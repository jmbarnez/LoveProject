local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")
local NodeMarket = require("src.systems.node_market")
local TechnicalIndicators = require("src.systems.technical_indicators")
local ChartRenderer = require("src.ui.nodes.chart_renderer")
local History = require("src.core.history")
local ChartAnimations = require("src.systems.chart_animations")
local PortfolioManager = require("src.managers.portfolio")

local Nodes = {}

function Nodes:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.selectedSymbol = "AST" -- Default node
    o.nodeDropdownOpen = false
    o.range = "1m"
    o.chartType = "candle"
    o.zoom = 1.0
    o.yScale = 1.0
    o.yOffset = 0.0
    o.xPanBars = 0
    o._xDragging = false
    o._yDragging = false
    o._yScaleDragging = false
    o.lastPrices = {}
    o.intervalSeconds = 60
    o.activeBottomTab = "portfolio"
    o.history = History.new(200)
    o.nodeViewStates = {} -- Store view state per node

    -- Trading interface state
    o.tradingMode = "buy" -- "buy" or "sell"
    o.buyAmount = ""
    o.sellAmount = ""
    o.buyInputActive = false
    o.sellInputActive = false
    o.orderType = "market" -- "market" or "limit"
    o.limitPrice = ""
    o.limitPriceInputActive = false

    -- Push initial view state
    if o.history then
        o.history:push({
            range = o.range,
            zoom = o.zoom,
            yScale = o.yScale,
            yOffset = o.yOffset,
            xPanBars = o.xPanBars,
            selectedSymbol = o.selectedSymbol,
            chartType = o.chartType,
        })
    end
    return o
end

-- #region Drawing Helpers (Chart, Indicators)
local function minmax(samples, i0, i1)
    local mn, mx = math.huge, -math.huge
    local n = #samples
    local validStart = math.max(1, i0)
    local validEnd = math.min(n, i1)
    for i = validStart, validEnd do
        local s = samples[i]
        if s then
            mn = math.min(mn, s.l)
            mx = math.max(mx, s.h)
        end
    end
    if not (mn < math.huge) then
        mn, mx = 0, 1
        if n > 0 then
            local lastCandle = samples[n]
            mn, mx = lastCandle.l, lastCandle.h
        end
    end
    return mn, mx
end

local function drawCandles(samples, x, y, w, h, reqVisible, padL, padR, yScale, yOffset, startIndex)
    local n = #samples
    if n == 0 then return 0, 1, 8, 1, 0 end
    reqVisible = math.max(1, math.floor((reqVisible or n)))
    local i0 = math.floor(startIndex or (n - reqVisible + 1))
    local i1 = i0 + reqVisible - 1
    padL = math.max(0, padL or math.floor(reqVisible * 0.1))
    padR = math.max(0, padR or math.floor(reqVisible * 0.2))
    local totalSlots = reqVisible + padL + padR
    local cw = w / totalSlots
    local mn, mx = minmax(samples, i0, i1)
    local pad = (mx - mn) * 0.05
    mn, mx = mn - pad, mx + pad
    local baseCenter = 0.5 * (mn + mx)
    local baseRange = (mx - mn)
    yScale = math.max(0.1, yScale or 1.0)
    yOffset = yOffset or 0.0
    local viewRange = baseRange / yScale
    local viewCenter = baseCenter + yOffset
    mn, mx = viewCenter - viewRange * 0.5, viewCenter + viewRange * 0.5
    if mn == mx then mx = mn + 1 end
    local scaleY = h / (mx - mn)
    local gapPx = math.max(1, math.floor(cw * 0.2))  -- Increased gap between candles
    local bodyMax = math.max(1, math.floor(cw - gapPx))  -- Body width = candle width - gap

    Theme.setColor(Theme.colors.bg3)
    love.graphics.setLineWidth(1)
    for k = 0, 4 do
        local gy = y + h - (h * k / 4)
        love.graphics.line(x, math.floor(gy) + 0.5, x + w, math.floor(gy) + 0.5)
    end

    for i = i0, i1 do
        local s = samples[i]
        if s then
            local idx = i - i0
            local cx = x + (padL + idx) * cw + cw * 0.5
            local cxp = math.floor(cx) + 0.5
            local openY = y + h - (s.o - mn) * scaleY
            local closeY = y + h - (s.c - mn) * scaleY
            local highY = y + h - (s.h - mn) * scaleY
            local lowY = y + h - (s.l - mn) * scaleY
            if lowY < highY then highY, lowY = lowY, highY end
            local up = s.c >= s.o
            local bodyH = math.max(1, math.abs(closeY - openY))
            local bodyW = math.max(1, bodyMax)
            Theme.setColor(Theme.colors.bg3)
            love.graphics.setLineWidth(1)
            love.graphics.line(cxp, highY, cxp, lowY)
            Theme.setColor(up and Theme.colors.success or Theme.colors.danger)
            if bodyW <= 1.5 then
                love.graphics.line(cxp, openY, cxp, closeY)
            else
                local bx = math.floor(cx - bodyW * 0.5) + 0.5
                local by = math.floor(math.min(openY, closeY)) + 0.5
                love.graphics.rectangle("line", bx, by, bodyW, bodyH)
            end
        end
    end
    return mn, mx, cw, i0, i1
end

local function formatPrice(p)
    if p >= 100 then return string.format("%.2f", p) end
    if p >= 1 then return string.format("%.3f", p) end
    return string.format("%.5f", p)
end

-- Calculate slippage percentage for a given amount
local function calculateSlippage(amount, node)
    local depth = (node.liquidity and node.liquidity.orderBookDepth) or 1
    local slipFactor = (node.liquidity and node.liquidity.slippageFactor) or 1.0
    local slippage = math.min(0.10, (amount / depth) * slipFactor) * 100  -- Cap at 10%
    return slippage
end
-- #endregion

-- #region New UI Panel Drawing Functions
local function formatMarketCap(marketCap)
    if marketCap >= 1e9 then
        return string.format("$%.2fB", marketCap / 1e9)
    elseif marketCap >= 1e6 then
        return string.format("$%.2fM", marketCap / 1e6)
    else
        return string.format("$%.2f", marketCap)
    end
end

local function drawHeader(self, node, stats, x, y, w, h)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts.medium)
    local headerText = node.symbol .. "/GC"
    local textW = love.graphics.getFont():getWidth(headerText)
    love.graphics.print(headerText, x, y)

    -- Dropdown arrow
    local arrowText = "▼"
    local arrowW = love.graphics.getFont():getWidth(arrowText)
    local arrowX = x + textW + 8
    local arrowY = y + 2  -- Adjusted positioning
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print(arrowText, arrowX, arrowY)
    self._nodeDropdownButton = { x = x, y = y, w = arrowX + arrowW - x, h = 25 }  -- Reduced height

    -- Format market cap for display
    local function formatMarketCap(marketCap)
        if not marketCap then return "N/A" end
        if marketCap >= 1e9 then
            return string.format("$%.2fB", marketCap / 1e9)
        elseif marketCap >= 1e6 then
            return string.format("$%.2fM", marketCap / 1e6)
        else
            return string.format("$%.2f", marketCap)
        end
    end

    -- Price and change
    love.graphics.setFont(Theme.fonts.small)
    local priceStr = formatPrice(stats.price)
    local priceColor = Theme.colors.textHighlight
    local lastPrice = self.lastPrices[node.symbol]
    if lastPrice then
        if stats.price > lastPrice then priceColor = Theme.colors.positive
        elseif stats.price < lastPrice then priceColor = Theme.colors.negative end
    end
    Theme.setColor(priceColor)
    love.graphics.print(priceStr, x, y + 16)

    -- Market data points
    local dataPoints = {
        {"24h Chg", string.format("%+.2f%%", stats.changePct), stats.changePct >= 0 and Theme.colors.positive or Theme.colors.negative},
        {"Market Cap", formatMarketCap(node.marketCap)},
        {"Liquidity", formatMarketCap(node.liquidity and node.liquidity.orderBookDepth or 0)},
        {"24h Vol", formatMarketCap(node.liquidity and node.liquidity.volume24h or 0)},
        {"Supply", string.format("%.0fM", (node.supply or 0) / 1e6)}
    }
    -- Draw data points in two rows to save horizontal space
    love.graphics.setFont(Theme.fonts.small)
    local dataX = x + 140
    local rowSpacing = 14
    local colSpacing = 116
    
    -- First row (top)
    for i = 1, 3 do
        if dataPoints[i] then
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.print(dataPoints[i][1], dataX, y + 2)
            Theme.setColor(dataPoints[i][3] or Theme.colors.text)
            love.graphics.print(dataPoints[i][2], dataX, y + 14)
        end
        dataX = dataX + colSpacing
    end
    
    -- Second row (bottom) - shifted down for clearer separation
    dataX = x + 140
    for i = 4, 5 do
        if dataPoints[i] then
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.print(dataPoints[i][1], dataX, y + 28)
            Theme.setColor(dataPoints[i][3] or Theme.colors.text)
            love.graphics.print(dataPoints[i][2], dataX, y + 40)
        end
        dataX = dataX + colSpacing
    end

    -- Volatility regime badge (Calm / Normal / High)
    local vol = (stats.sigma or 0) * (stats.volMultiplier or 1)
    local regimeLabel = "Normal"
    local regimeColor = Theme.colors.warning or Theme.colors.accent
    if vol < 0.01 then
        regimeLabel = "Calm"
        regimeColor = Theme.colors.success
    elseif vol >= 0.03 then
        regimeLabel = "High Vol"
        regimeColor = Theme.colors.danger
    end
    local badgeText = regimeLabel
    love.graphics.setFont(Theme.fonts.small)
    local btW = love.graphics.getFont():getWidth(badgeText) + 10
    local badgeW, badgeH = btW, 16
    local badgeX, badgeY = x + w - badgeW - 8, y + 2
    Theme.setColor(regimeColor)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeW, badgeH, 6, 6)
    Theme.setColor(Theme.colors.bg0 or {0,0,0,1})
    love.graphics.printf(badgeText, badgeX, badgeY + 2, badgeW, "center")

    -- Buy/Sell pressure bar (left=Sell red, right=Buy green) - move to right side
    local pressure = (node.liquidity and node.liquidity.buyPressure) or 0.5
    local barW, barH = 110, 4
    local barX, barY = x + w - barW - 8, y + 44
    Theme.setColor(Theme.colors.bg3)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 2, 2)
    local buyW = math.floor(barW * pressure)
    local sellW = barW - buyW
    Theme.setColor(Theme.colors.danger)
    love.graphics.rectangle("fill", barX + buyW, barY, sellW, barH, 2, 2)
    Theme.setColor(Theme.colors.success)
    love.graphics.rectangle("fill", barX, barY, buyW, barH, 2, 2)
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Flow", barX, barY - 10)
end

local function drawChartPanel(self, node, x, y, w, h)
    ChartRenderer.draw(self, node, x, y, w, h)
end


-- Draw a compact global stats strip showing total market cap and 24h volume
local function drawGlobalStrip(self, x, y, w, h)
    local gs = NodeMarket.getGlobalStats()
    if not gs then return end

    -- Background
    Theme.drawGradientGlowRect(x, y, w, h, 3, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    love.graphics.setFont(Theme.fonts.small)
    Theme.setColor(Theme.colors.textSecondary)

    local capStr = string.format("Global Cap: %s", formatMarketCap(gs.totalMarketCap or 0))
    local volStr = string.format("Global 24h Vol: %s", formatMarketCap(gs.totalVolume24h or 0))
    local nodesStr = string.format("Assets: %d", gs.nodeCount or 0)

    local pad = 8
    love.graphics.print(capStr, x + pad, y + 4)

    local volW = love.graphics.getFont():getWidth(volStr)
    local nodesW = love.graphics.getFont():getWidth(nodesStr)
    -- Right-align vol and nodes
    love.graphics.print(volStr, x + w - pad - volW, y + 4)

    Theme.setColor(Theme.colors.text)
    love.graphics.print(nodesStr, x + (w - nodesW) / 2, y + 4)
end



local function drawBottomPanel(self, player, x, y, w, h)
    Theme.drawGradientGlowRect(x, y, w, h, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    -- Tabs - more compact
    local holdings = PortfolioManager.getAllHoldings()
    local holdingCount = 0
    for _ in pairs(holdings) do
        holdingCount = holdingCount + 1
    end
    local tabs = { "Portfolio (" .. holdingCount .. ")", "Transactions", "Activity", "Resources" }  -- Updated tab names
    self._bottomTabs = {}
    local tabX = x + 8  -- Reduced margin
    for _, tabName in ipairs(tabs) do
        local id = string.lower(string.match(tabName, "%a+"))
        local selected = self.activeBottomTab == id
        local textW = Theme.fonts.small:getWidth(tabName)  -- Use small font for tabs
        Theme.setColor(selected and Theme.colors.textHighlight or Theme.colors.textSecondary)
        love.graphics.setFont(Theme.fonts.small)  -- Reduced font size
        love.graphics.print(tabName, tabX, y + 6)  -- Reduced spacing
        if selected then love.graphics.rectangle("fill", tabX, y + 22, textW, 2) end  -- Adjusted underline position
        table.insert(self._bottomTabs, { x = tabX, y = y + 6, w = textW, h = 20, id = id })  -- Reduced height
        tabX = tabX + textW + 15  -- Reduced spacing between tabs
    end

    -- Content - more compact
    if self.activeBottomTab == "portfolio" then
        local funds = PortfolioManager.getAvailableFunds()
        local holdings = PortfolioManager.getAllHoldings()
        love.graphics.setFont(Theme.fonts.small)
        Theme.setColor(Theme.colors.text)
        love.graphics.print("Resources: " .. formatPrice(funds) .. " GC", x + 12, y + 40)

        local yPos = y + 60
        for symbol, holding in pairs(holdings) do
            if holding.quantity > 0.0001 then
                local nodeForStats = NodeMarket.getNodeBySymbol(symbol)
                local stats = nodeForStats and NodeMarket.getStats(nodeForStats)
                local value = stats and (stats.price * holding.quantity) or 0
                love.graphics.print(string.format("%s: %.4f (%s GC)", symbol, holding.quantity, formatPrice(value)), x + 12, yPos)
                yPos = yPos + 18
            end
        end
    elseif self.activeBottomTab == "transactions" then
        local node = NodeMarket.getNodeBySymbol(self.selectedSymbol)
        local transactions = node and NodeMarket.getNodeTransactions(self.selectedSymbol) or {}
        print("UI: Checking transactions for", self.selectedSymbol, "found:", #transactions)  -- Debug output
        love.graphics.setFont(Theme.fonts.small)

        -- Table headers
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print("TIME", x + 12, y + 40)
        love.graphics.print("TYPE", x + 100, y + 40)
        love.graphics.print("TRADER", x + 160, y + 40)
        love.graphics.print("AMOUNT", x + 230, y + 40)
        love.graphics.print("PRICE", x + 320, y + 40)
        love.graphics.print("VALUE", x + 400, y + 40)

        -- Transaction rows
        local yPos = y + 58
        local maxRows = math.floor((h - 80) / 16)  -- Calculate how many rows fit
        local startIndex = math.max(1, #transactions - maxRows + 1)  -- Show most recent transactions

        for i = #transactions, startIndex, -1 do  -- Iterate backwards to show newest first
            local tx = transactions[i]
            if tx then
                -- Time
                Theme.setColor(Theme.colors.textSecondary)
                local timeStr = os.date("%H:%M:%S", tx.timestamp)
                love.graphics.print(timeStr, x + 12, yPos)

                -- Type with color coding
                local typeColor = Theme.colors.text
                if tx.type == "BUY" or tx.type == "LIMIT_BUY" then
                    typeColor = Theme.colors.positive
                elseif tx.type == "SELL" or tx.type == "LIMIT_SELL" then
                    typeColor = Theme.colors.negative
                end
                Theme.setColor(typeColor)
                local displayType = tx.type:gsub("LIMIT_", "L.")  -- Shorten LIMIT_BUY to L.BUY
                love.graphics.print(displayType, x + 100, yPos)

                -- Trader (Player vs AI)
                Theme.setColor(tx.isPlayerTrade and Theme.colors.textHighlight or Theme.colors.textSecondary)
                local traderText = tx.isPlayerTrade and "PLAYER" or "AI"
                love.graphics.print(traderText, x + 160, yPos)

                -- Amount
                Theme.setColor(Theme.colors.text)
                love.graphics.print(string.format("%.4f", tx.quantity), x + 230, yPos)

                -- Price
                love.graphics.print(formatPrice(tx.price), x + 320, yPos)

                -- Total Value
                local totalValue = tx.quantity * tx.price
                love.graphics.print(formatPrice(totalValue), x + 400, yPos)

                yPos = yPos + 16
                if yPos > y + h - 20 then break end  -- Stop if we're running out of space
            end
        end

        if #transactions == 0 then
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.printf("No transactions for " .. (self.selectedSymbol or "this token") .. " yet.", x, y + 80, w, "center")
        end
    elseif self.activeBottomTab == "resources" then
        local funds = PortfolioManager.getAvailableFunds()
        love.graphics.setFont(Theme.fonts.small)
        Theme.setColor(Theme.colors.text)
        love.graphics.print("Available Funds: " .. formatPrice(funds) .. " GC", x + 12, y + 40)

        -- Could add more resource information here
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print("Total Portfolio Value: Calculating...", x + 12, y + 60)
    else
        love.graphics.setFont(Theme.fonts.small)
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.printf("Not implemented yet.", x, y + 40, w, "center")
    end
end

local function drawBuyInterface(self, player, node, stats, x, y, w, h)
    love.graphics.setFont(Theme.fonts.small)
    local font = love.graphics.getFont()
    local lineHeight = font:getHeight() + 4

    local yPos = y + 8

    -- Market info section
    local funds = PortfolioManager.getAvailableFunds()
    local lastPrice = self.lastPrices[node.symbol]
    local priceChange = lastPrice and (stats.price - lastPrice) or 0
    local priceChangeColor = priceChange > 0 and Theme.colors.positive or
                           priceChange < 0 and Theme.colors.negative or Theme.colors.text

    -- Current price with larger font
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Current Price:", x, yPos)
    Theme.setColor(priceChangeColor)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.print(formatPrice(stats.price) .. " GC", x + 130, yPos - 2)
    love.graphics.setFont(Theme.fonts.small)
    yPos = yPos + lineHeight + 2

    -- Available funds with smaller display
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Available Balance:", x, yPos)
    Theme.setColor(Theme.colors.text)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.print(formatPrice(funds) .. " GC", x + 150, yPos - 2)
    love.graphics.setFont(Theme.fonts.small)
    yPos = yPos + lineHeight + 8

    -- Amount input section
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Purchase Amount (" .. node.symbol .. "):", x, yPos)
    yPos = yPos + lineHeight

    local inputW = w - 16
    local inputH = 32  -- Taller input field
    local inputX = x + 8
    local inputY = yPos

    -- Input field background
    Theme.drawGradientGlowRect(inputX, inputY, inputW, inputH, 4,
        self.buyInputActive and Theme.colors.bg0 or Theme.colors.bg1,
        Theme.colors.bg0,
        self.buyInputActive and Theme.colors.accent or Theme.colors.border,
        Theme.effects.glowWeak)
        
    -- Show slippage if amount is entered (convert token amount to GC value)
    if self._buyAmount and #self._buyAmount > 0 then
        local amount = tonumber(self._buyAmount) or 0
        if amount > 0 then
            local gcValue = amount * stats.price
            local slippage = calculateSlippage(gcValue, node)
            local slippageText = string.format("Slippage: %.2f%%", slippage)
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.print(slippageText, inputX, inputY + inputH + 4)
        end
    end

    -- Input text with smaller font
    Theme.setColor(Theme.colors.text)
    local displayText = self.buyAmount == "" and "0.0000" or self.buyAmount
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.print(displayText, inputX + 8, inputY + 6)

    -- Blinking cursor when active
    if self.buyInputActive and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local textWidth = love.graphics.getFont():getWidth(displayText)
        love.graphics.rectangle("fill", inputX + 8 + textWidth + 2, inputY + 4, 1, inputH - 8)
    end
    love.graphics.setFont(Theme.fonts.small)

    self._buyAmountInput = { x = inputX, y = inputY, w = inputW, h = inputH }
    yPos = yPos + inputH + 12

    -- Cost calculation with better formatting
    local amount = tonumber(self.buyAmount) or 0
    local totalCost = amount * stats.price
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Total Cost:", x, yPos)
    Theme.setColor(totalCost > funds and Theme.colors.danger or Theme.colors.text)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.print(formatPrice(totalCost) .. " GC", x + 110, yPos - 2)
    love.graphics.setFont(Theme.fonts.small)
    yPos = yPos + lineHeight + 4

    -- Quick amount buttons with better layout
    local buttonW = (w - 20) / 4  -- 4 buttons instead of 3
    local buttonH = 26
    local quickAmounts = {
        { label = "10%", value = math.floor(funds * 0.10 / stats.price * 10000) / 10000 },
        { label = "25%", value = math.floor(funds * 0.25 / stats.price * 10000) / 10000 },
        { label = "50%", value = math.floor(funds * 0.50 / stats.price * 10000) / 10000 },
        { label = "MAX", value = math.floor(funds / stats.price * 10000) / 10000 }
    }

    self._quickBuyButtons = {}
    for i, qa in ipairs(quickAmounts) do
        local btnX = x + 4 + (i - 1) * (buttonW + 4)
        local btnY = yPos

        Theme.drawGradientGlowRect(btnX, btnY, buttonW, buttonH, 3,
            Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak)
        Theme.setColor(Theme.colors.text)
        love.graphics.printf(qa.label, btnX, btnY + 6, buttonW, "center")

        table.insert(self._quickBuyButtons, { x = btnX, y = btnY, w = buttonW, h = buttonH, value = qa.value })
    end
    yPos = yPos + buttonH + 12

    -- Execute buy button - larger and more prominent
    local executeW = w - 16
    local executeH = 40
    local executeX = x + 8
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

local function drawSellInterface(self, player, node, stats, x, y, w, h)
    love.graphics.setFont(Theme.fonts.small)
    local font = love.graphics.getFont()
    local lineHeight = font:getHeight() + 4
    yPos = yPos + lineHeight + 8

    -- Amount input
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Amount:", x, yPos)
    yPos = yPos + lineHeight

    local inputW = w - 8
    local inputH = 26
    local inputX = x
    local inputY = yPos

    -- Input field background
    Theme.drawGradientGlowRect(inputX, inputY, inputW, inputH, 3,
        self.sellInputActive and Theme.colors.bg0 or Theme.colors.bg1,
        Theme.colors.bg0,
        self.sellInputActive and Theme.colors.accent or Theme.colors.border,
        Theme.effects.glowWeak)

    -- Input text
    Theme.setColor(Theme.colors.text)
    local displayText = self.sellAmount == "" and "0.0000" or self.sellAmount
    love.graphics.print(displayText, inputX + 4, inputY + 4)

    -- Blinking cursor when active
    if self.sellInputActive and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local textWidth = font:getWidth(displayText)
        love.graphics.rectangle("fill", inputX + 4 + textWidth + 2, inputY + 2, 1, inputH - 4)
    end

    self._sellAmountInput = { x = inputX, y = inputY, w = inputW, h = inputH }
    yPos = yPos + inputH + 8
    
    -- Show slippage if amount is entered
    if self.sellAmount and #self.sellAmount > 0 then
        local amount = tonumber(self.sellAmount) or 0
        if amount > 0 then
            local slippage = calculateSlippage(amount * stats.price, node)  -- Convert to GC value
            local slippageText = string.format("Slippage: %.2f%%", slippage)
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.print(slippageText, x, yPos)
            yPos = yPos + lineHeight + 4
        end
    end

    -- Revenue calculation
    local amount = tonumber(self.sellAmount) or 0
    local totalRevenue = amount * stats.price
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Total Revenue:", x, yPos)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(formatPrice(totalRevenue) .. " GC", x + 85, yPos)
    yPos = yPos + lineHeight + 8

    -- Quick amount buttons
    local buttonW = (w - 16) / 3
    local buttonH = 22
    local quickAmounts = {
        { label = "25%", value = math.floor(holding.quantity * 0.25 * 10000) / 10000 },
        { label = "50%", value = math.floor(holding.quantity * 0.50 * 10000) / 10000 },
        { label = "ALL", value = holding.quantity }
    }

    self._quickSellButtons = {}
    for i, qa in ipairs(quickAmounts) do
        local btnX = x + (i - 1) * (buttonW + 4)
        local btnY = yPos

        Theme.drawGradientGlowRect(btnX, btnY, buttonW, buttonH, 3,
            Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak)
        Theme.setColor(Theme.colors.text)
        love.graphics.printf(qa.label, btnX, btnY + 4, buttonW, "center")

        table.insert(self._quickSellButtons, { x = btnX, y = btnY, w = buttonW, h = buttonH, value = qa.value })
    end
    yPos = yPos + buttonH + 8

    -- Execute sell button
    local executeW = w - 8
    local executeH = 32
    local executeX = x
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

local function drawTradingInterface(self, player, node, stats, x, y, w, h)
    -- Main container background
    Theme.drawGradientGlowRect(x, y, w, h, 6, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    -- Trading mode tabs (Buy/Sell)
    local tabW = w / 2
    local tabH = 28
    local buyTabX = x + 4
    local sellTabX = x + 4 + tabW
    local tabY = y + 4

    -- Buy tab
    local buySelected = self.tradingMode == "buy"
    Theme.drawGradientGlowRect(buyTabX, tabY, tabW - 4, tabH, 4,
        buySelected and Theme.colors.success or Theme.colors.bg2,
        Theme.colors.bg1,
        buySelected and Theme.colors.success or Theme.colors.border,
        Theme.effects.glowWeak)
    Theme.setColor(buySelected and Theme.colors.textHighlight or Theme.colors.textSecondary)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.printf("BUY", buyTabX, tabY + 7, tabW - 4, "center")

    -- Sell tab
    local sellSelected = self.tradingMode == "sell"
    Theme.drawGradientGlowRect(sellTabX, tabY, tabW - 4, tabH, 4,
        sellSelected and Theme.colors.danger or Theme.colors.bg2,
        Theme.colors.bg1,
        sellSelected and Theme.colors.danger or Theme.colors.border,
        Theme.effects.glowWeak)
    Theme.setColor(sellSelected and Theme.colors.textHighlight or Theme.colors.textSecondary)
    love.graphics.printf("SELL", sellTabX, tabY + 7, tabW - 4, "center")

    -- Store tab areas for click detection
    self._buyTab = { x = buyTabX, y = tabY, w = tabW - 4, h = tabH }
    self._sellTab = { x = sellTabX, y = tabY, w = tabW - 4, h = tabH }

    -- Content area
    local contentY = y + tabH + 8
    local contentH = h - tabH - 12

    if self.tradingMode == "buy" then
        drawBuyInterface(self, player, node, stats, x + 4, contentY, w - 8, contentH)
    else
        drawSellInterface(self, player, node, stats, x + 4, contentY, w - 8, contentH)
    end
end

-- #endregion

function Nodes:draw(player, x, y, w, h)
    NodeMarket.init()
    PortfolioManager.init()  -- Ensure portfolio manager is initialized
    local nodes = NodeMarket.getNodes()
    if not self.selectedSymbol then self.selectedSymbol = nodes[1] and nodes[1].symbol end
    local node = NodeMarket.getNodeBySymbol(self.selectedSymbol)
    if not node then return end
    local stats = NodeMarket.getStats(node)

    -- Layout definitions with trading interface in bottom-right
    local headerH = 56  -- Tighter header height
    local globalStripH = 18  -- Tighter global strip
    local bottomPanelH = 250
    local margin = 6
    local tradingW = 300  -- Wider trading interface
    local tradingH = 240  -- Height for trading interface

    -- Chart takes full width
    local chartW = w - margin * 2
    local chartH = h - headerH - globalStripH - bottomPanelH - margin * 5
    local chartX = x + margin
    local chartY = y + headerH + globalStripH + margin * 2

    -- Bottom panel leaves space for trading interface
    local bottomPanelW = chartW - tradingW - margin
    local bottomPanelX = chartX
    local bottomPanelY = chartY + chartH + margin

    -- Trading interface positioned in bottom-right
    local tradingX = bottomPanelX + bottomPanelW + margin
    local tradingY = bottomPanelY

    -- Draw components
    drawHeader(self, node, stats, x + margin, y + margin, w - margin * 2, headerH)
    drawGlobalStrip(self, x + margin, y + headerH + margin, w - margin * 2, globalStripH)
    drawChartPanel(self, node, chartX, chartY, chartW, chartH)
    drawBottomPanel(self, player, bottomPanelX, bottomPanelY, bottomPanelW, bottomPanelH)

    -- Trading interface in bottom-right
    drawTradingInterface(self, player, node, stats, tradingX, tradingY, tradingW, tradingH)

    -- Draw node dropdown if open
    if self.nodeDropdownOpen and self._nodeDropdownButton then
        local btn = self._nodeDropdownButton
        local dropdownX = btn.x
        local dropdownY = btn.y + btn.h
        local dropdownW = 200
        local rowH = 28
        Theme.drawGradientGlowRect(dropdownX, dropdownY, dropdownW, #nodes * rowH + 8, 4, Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)
        self._nodeDropdownItems = {}
        for i, c in ipairs(nodes) do
            local itemY = dropdownY + 4 + (i - 1) * rowH
            local rect = { x = dropdownX, y = itemY, w = dropdownW, h = rowH }
            local mx, my = Viewport.getMousePosition()
            if Util.rectContains(mx, my, rect.x, rect.y, rect.w, rect.h) then
                Theme.drawGradientGlowRect(rect.x, rect.y, rect.w, rect.h, 4, Theme.colors.bg3, Theme.colors.bg2, Theme.colors.accent, Theme.effects.glowWeak)
            end
            Theme.setColor(Theme.colors.text)
            love.graphics.print(c.symbol .. " - " .. c.name, dropdownX + 8, itemY + 6)
            table.insert(self._nodeDropdownItems, { rect = rect, node = c })
        end
    end
end

function Nodes:update(dt)
    NodeMarket.update(dt)
    ChartAnimations.update(dt)
    local nodes = NodeMarket.getNodes()
    if not nodes then return end
    for _, node in ipairs(nodes) do
        local stats = NodeMarket.getStats(node)
        if stats and stats.price then
            self.lastPrices[node.symbol] = stats.price
        end
    end
end

function Nodes:mousepressed(player, x, y, button)
    if button ~= 1 then return false end

    -- Trading interface interactions (highest priority)

    -- Trading mode tabs
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

    -- Input field clicks
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

    -- Quick buy buttons
    if self._quickBuyButtons then
        for _, btn in ipairs(self._quickBuyButtons) do
            if Util.rectContains(x, y, btn.x, btn.y, btn.w, btn.h) then
                self.buyAmount = tostring(btn.value)
                return true
            end
        end
    end

    -- Quick sell buttons
    if self._quickSellButtons then
        for _, btn in ipairs(self._quickSellButtons) do
            if Util.rectContains(x, y, btn.x, btn.y, btn.w, btn.h) then
                self.sellAmount = tostring(btn.value)
                return true
            end
        end
    end

    -- Execute buttons
    if self._executeBuyButton and self._executeBuyButton.enabled and
       Util.rectContains(x, y, self._executeBuyButton.x, self._executeBuyButton.y, self._executeBuyButton.w, self._executeBuyButton.h) then
        self:executeBuy(player)
        return true
    end

    if self._executeSellButton and self._executeSellButton.enabled and
       Util.rectContains(x, y, self._executeSellButton.x, self._executeSellButton.y, self._executeSellButton.w, self._executeSellButton.h) then
        self:executeSell(player)
        return true
    end

    -- Clear input focus if clicking elsewhere
    self.buyInputActive = false
    self.sellInputActive = false

    -- Node dropdown
    if self.nodeDropdownOpen and self._nodeDropdownItems then
        for _, item in ipairs(self._nodeDropdownItems) do
            if Util.rectContains(x, y, item.rect.x, item.rect.y, item.rect.w, item.rect.h) then
                -- Only update if we're actually changing nodes
                if self.selectedSymbol ~= item.node.symbol then
                    -- Save current node's view state
                    if self.nodeViewStates then
                        self.nodeViewStates[self.selectedSymbol] = {
                            yScale = self.yScale,
                            yOffset = self.yOffset,
                            xPanBars = self.xPanBars,
                            zoom = self.zoom
                        }
                    end
                    
                    -- Update to new node
                    self.selectedSymbol = item.node.symbol
                    
                    -- Restore new node's view state or reset to defaults
                    local savedState = self.nodeViewStates and self.nodeViewStates[self.selectedSymbol]
                    if savedState then
                        self.yScale = savedState.yScale
                        self.yOffset = savedState.yOffset
                        self.xPanBars = savedState.xPanBars
                        self.zoom = savedState.zoom
                    else
                        -- Reset to default view for new node
                        self.yScale = 1.0
                        self.yOffset = 0.0
                        self.xPanBars = 0
                        self.zoom = 1.0
                    end
                end
                self.nodeDropdownOpen = false
                return true
            end
        end
    end

    if self._nodeDropdownButton and Util.rectContains(x, y, self._nodeDropdownButton.x, self._nodeDropdownButton.y, self._nodeDropdownButton.w, self._nodeDropdownButton.h) then
        self.nodeDropdownOpen = not self.nodeDropdownOpen
        return true
    end
    -- If we clicked outside the dropdown, close it
    self.nodeDropdownOpen = false

    -- Y-axis scale dragging (check first, higher priority than chart dragging)
    if self._yAxisLabels then
        for _, label in ipairs(self._yAxisLabels) do
            if Util.rectContains(x, y, label.x, label.y, label.w, label.h) then
                self._yScaleDragging = true
                return true
            end
        end
    end

    -- Chart dragging
    if self._chartRect and Util.rectContains(x, y, self._chartRect.x, self._chartRect.y, self._chartRect.w, self._chartRect.h) then
        self._xDragging = true
        self._yDragging = true
        return true
    end

    -- Range buttons
    if self._rangeButtons then
        for _, rb in ipairs(self._rangeButtons) do
            if Util.rectContains(x, y, rb.x, rb.y, rb.w, rb.h) then
                if self.history then
                    self.history:push({
                        range = self.range,
                        zoom = self.zoom,
                        yScale = self.yScale,
                        yOffset = self.yOffset,
                        xPanBars = self.xPanBars,
                        selectedSymbol = self.selectedSymbol,
                        chartType = self.chartType,
                    })
                end
                self.range = rb.id
                local secs = { 
                    ["5s"]=5, ["15s"]=15, ["30s"]=30, 
                    ["1m"]=60, ["5m"]=300, ["15m"]=900, 
                    ["30m"]=1800, ["1h"]=3600, ["4h"]=14400, 
                    ["1d"]=86400 
                }
                self.intervalSeconds = secs[rb.id]
                return true
            end
        end
    end

    -- Style buttons (Candle / Line)
    if self._styleButtons then
        for _, sb in ipairs(self._styleButtons) do
            if Util.rectContains(x, y, sb.x, sb.y, sb.w, sb.h) then
                if self.history then
                    self.history:push({
                        range = self.range,
                        zoom = self.zoom,
                        yScale = self.yScale,
                        yOffset = self.yOffset,
                        xPanBars = self.xPanBars,
                        selectedSymbol = self.selectedSymbol,
                        chartType = self.chartType,
                    })
                end
                self.chartType = sb.id
                return true
            end
        end
    end


    -- Bottom tabs
    if self._bottomTabs then
        for _, tab in ipairs(self._bottomTabs) do
            if Util.rectContains(x, y, tab.x, tab.y, tab.w, tab.h) then
                self.activeBottomTab = tab.id
                return true
            end
        end
    end

    return false
end

function Nodes:mousereleased(player, x, y, button)
    self._xDragging = false
    self._yDragging = false
    self._yScaleDragging = false
    return false
end

function Nodes:mousemoved(player, x, y, dx, dy)
    -- Handle y-axis scale dragging (higher priority)
    if self._yScaleDragging then
        -- Adjust scale based on vertical drag
        local scaleFactor = 1 + (dy * 0.01)  -- Sensitivity adjustment
        self.yScale = math.max(0.1, math.min(20.0, (self.yScale or 1.0) * scaleFactor))
        return true
    end

    if self._chartRect and (self._yDragging or self._xDragging) then
        if self._yDragging then
            local node = NodeMarket.getNodeBySymbol(self.selectedSymbol)
            if not node then return false end
            local candles = NodeMarket.getCandles(node)
            if #candles > 1 then
                local n = #candles
                local j0 = math.max(1, n - math.max(1, math.floor((self._chartRect.w / 8) / self.zoom)) + 1)
                local mn, mx = minmax(candles, j0, n)
                local baseRange = (mx - mn) + 2 * ((mx - mn) * 0.05)
                local viewRange = baseRange / self.yScale
                local pricePerPixel = viewRange / self._chartRect.h
                self.yOffset = (self.yOffset or 0) + dy * pricePerPixel
            end
        end
        if self._xDragging then
            local barsPerPixel = 1 / (8 * self.zoom)
            -- Invert dx so dragging right shows older data (pan left), dragging left shows newer data (pan right)
            self.xPanBars = (self.xPanBars or 0) - dx * barsPerPixel
        end
        return true
    end
    return false
end

function Nodes:wheelmoved(player, dx, dy)
    local mx, my = Viewport.getMousePosition()
    if self._chartRect and Util.rectContains(mx, my, self._chartRect.x, self._chartRect.y, self._chartRect.w, self._chartRect.h) then
        if self.history then
            self.history:push({
                range = self.range,
                zoom = self.zoom,
                yScale = self.yScale,
                yOffset = self.yOffset,
                xPanBars = self.xPanBars,
                selectedSymbol = self.selectedSymbol,
                chartType = self.chartType,
            })
        end
        local factor = (dy > 0) and 1.2 or 1 / 1.2
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            self.yScale = math.max(0.1, math.min(20.0, (self.yScale or 1.0) * factor))
        else
            self.zoom = math.max(0.05, math.min(32.0, (self.zoom or 1.0) * factor))
            self.yScale = math.max(0.1, math.min(20.0, (self.yScale or 1.0) * factor))
        end
        return true
    end
    return false
end

function Nodes:keypressed(player, key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if ctrl and key == "z" and self.history then
        local s = self.history:undo()
        if s then
            self.range = s.range
            self.zoom = s.zoom
            self.yScale = s.yScale
            self.yOffset = s.yOffset
            self.xPanBars = s.xPanBars
            self.selectedSymbol = s.selectedSymbol
            self.chartType = s.chartType or self.chartType
            return true
        end
    elseif ctrl and key == "y" and self.history then
        local s = self.history:redo()
        if s then
            self.range = s.range
            self.zoom = s.zoom
            self.yScale = s.yScale
            self.yOffset = s.yOffset
            self.xPanBars = s.xPanBars
            self.selectedSymbol = s.selectedSymbol
            self.chartType = s.chartType or self.chartType
            return true
        end
    end
    return false
end

function Nodes:textinput(text)
    -- Handle numeric input for trading amounts
    if text:match("^[0-9%.]+$") then  -- Only allow numbers and decimal points
        if self.buyInputActive then
            -- Prevent multiple decimal points
            if text == "." and self.buyAmount:find("%.") then
                return true
            end
            self.buyAmount = self.buyAmount .. text
            return true
        elseif self.sellInputActive then
            -- Prevent multiple decimal points
            if text == "." and self.sellAmount:find("%.") then
                return true
            end
            self.sellAmount = self.sellAmount .. text
            return true
        end
    end
    return false
end

function Nodes:keypressed(key)
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
        -- Execute trade on Enter
        if self.buyInputActive and self._executeBuyButton and self._executeBuyButton.enabled then
            self:executeBuy(self.player)
            return true
        elseif self.sellInputActive and self._executeSellButton and self._executeSellButton.enabled then
            self:executeSell(self.player)
            return true
        end
    elseif key == "escape" then
        -- Clear input focus on Escape
        self.buyInputActive = false
        self.sellInputActive = false
        return true
    end
    return false
end

-- Trading execution functions
function Nodes:executeBuy(player)
    if not player then return end

    local amount = tonumber(self.buyAmount) or 0
    if amount <= 0 then return end

    local node = NodeMarket.getNodeBySymbol(self.selectedSymbol)
    if not node then return end

    local stats = NodeMarket.getStats(node)
    local totalCost = amount * stats.price
    local funds = PortfolioManager.getAvailableFunds()

    if totalCost > funds then
        print("Insufficient funds for purchase")
        return
    end

    -- Place order via PortfolioManager (handles market submission + portfolio updates)
    local success, message = PortfolioManager.placeBuyOrder(self.selectedSymbol, amount, stats.price, false)

    if success then
        -- Clear the input after successful trade
        self.buyAmount = ""
        self.buyInputActive = false

        -- Show success message or notification
        print("Successfully bought", amount, self.selectedSymbol, "for", formatPrice(totalCost), "GC")
    else
        print("Trade execution failed")
    end
end

function Nodes:executeSell(player)
    if not player then return end

    local amount = tonumber(self.sellAmount) or 0
    if amount <= 0 then return end

    local node = NodeMarket.getNodeBySymbol(self.selectedSymbol)
    if not node then return end

    local holdings = PortfolioManager.getAllHoldings()
    local holding = holdings[self.selectedSymbol] or { quantity = 0 }

    if amount > holding.quantity then
        print("Insufficient holdings for sale")
        return
    end

    local stats = NodeMarket.getStats(node)
    local totalRevenue = amount * stats.price

    -- Place order via PortfolioManager (handles market submission + portfolio updates)
    local success, message = PortfolioManager.placeSellOrder(self.selectedSymbol, amount, stats.price, false)

    if success then
        -- Clear the input after successful trade
        self.sellAmount = ""
        self.sellInputActive = false

        -- Show success message or notification
        print("Successfully sold", amount, self.selectedSymbol, "for", formatPrice(totalRevenue), "GC")

        -- PortfolioManager already updated holdings and funds
    else
        print("Trade execution failed")
    end
end

return Nodes
