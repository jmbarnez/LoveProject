local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")
local NodeMarket = require("src.systems.node_market")
local PortfolioManager = require("src.managers.portfolio")
local ChartRenderer = require("src.ui.nodes.chart_renderer")
local Log = require("src.core.log")

local ChartView = {}

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

local function formatPrice(p)
    if p >= 100 then return string.format("%.2f", p) end
    if p >= 1 then return string.format("%.3f", p) end
    return string.format("%.5f", p)
end

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

local function drawHeader(self, node, stats, layout)
    Theme.setColor(Theme.colors.textHighlight)
    love.graphics.setFont(Theme.fonts.medium)
    local headerText = node.symbol .. "/GC"
    love.graphics.print(headerText, layout.x, layout.y)

    local nodes = NodeMarket.getNodes()
    local nodeOptions = {}
    for _, nodeInfo in ipairs(nodes) do
        table.insert(nodeOptions, nodeInfo.symbol .. " - " .. nodeInfo.name)
    end

    self.nodeDropdown:setOptions(nodeOptions)
    self.nodeDropdown:setPosition(layout.x, layout.y)
    self.nodeDropdown:drawButtonOnly(layout.mx, layout.my)

    love.graphics.setFont(Theme.fonts.small)
    local priceStr = formatPrice(stats.price)
    local priceColor = Theme.colors.textHighlight
    local lastPrice = self.lastPrices[node.symbol]
    if lastPrice then
        if stats.price > lastPrice then
            priceColor = Theme.colors.positive
        elseif stats.price < lastPrice then
            priceColor = Theme.colors.negative
        end
    end
    Theme.setColor(priceColor)
    love.graphics.print(priceStr, layout.x, layout.y + 16)

    local dataPoints = {
        { "Price", formatPrice(stats.price), Theme.colors.textHighlight },
        { "Market Cap", formatMarketCap(stats.marketCap) }
    }

    love.graphics.setFont(Theme.fonts.small)
    local dataX = layout.x + 140
    local rowSpacing = 14
    local colSpacing = 116

    for _, point in ipairs(dataPoints) do
        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print(point[1], dataX, layout.y + 2)
        Theme.setColor(point[3] or Theme.colors.text)
        love.graphics.print(point[2], dataX, layout.y + 14)
        dataX = dataX + colSpacing
    end

    local pressure = (node.liquidity and node.liquidity.buyPressure) or 0.5
    local barW, barH = 110, 4
    local barX, barY = layout.x + layout.w - barW - 8, layout.y + 44
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

local function drawGlobalStrip(layout)
    local gs = NodeMarket.getGlobalStats()
    if not gs then return end

    Theme.drawGradientGlowRect(layout.x, layout.y, layout.w, layout.h, 3,
        Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    love.graphics.setFont(Theme.fonts.small)
    Theme.setColor(Theme.colors.textSecondary)

    local nodesStr = string.format("Assets: %d", gs.nodeCount or 0)
    local nodesW = love.graphics.getFont():getWidth(nodesStr)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(nodesStr, layout.x + (layout.w - nodesW) / 2, layout.y + 4)
end

local function drawBottomPanel(self, player, layout)
    Theme.drawGradientGlowRect(layout.x, layout.y, layout.w, layout.h, 4,
        Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local holdings = PortfolioManager.getAllHoldings()
    local holdingCount = 0
    for _ in pairs(holdings) do
        holdingCount = holdingCount + 1
    end

    local tabs = { "Portfolio (" .. holdingCount .. ")", "Transactions" }
    self._bottomTabs = {}
    local tabX = layout.x + 8
    for _, tabName in ipairs(tabs) do
        local id = string.lower(string.match(tabName, "%a+"))
        local selected = self.activeBottomTab == id
        local textW = Theme.fonts.small:getWidth(tabName)
        Theme.setColor(selected and Theme.colors.textHighlight or Theme.colors.textSecondary)
        love.graphics.setFont(Theme.fonts.small)
        love.graphics.print(tabName, tabX, layout.y + 6)
        if selected then
            love.graphics.rectangle("fill", tabX, layout.y + 22, textW, 2)
        end
        table.insert(self._bottomTabs, { x = tabX, y = layout.y + 6, w = textW, h = 20, id = id })
        tabX = tabX + textW + 15
    end

    if self.activeBottomTab == "portfolio" then
        local funds = PortfolioManager.getAvailableFunds()
        love.graphics.setFont(Theme.fonts.small)
        Theme.setColor(Theme.colors.text)
        love.graphics.print("Resources: " .. formatPrice(funds) .. " GC", layout.x + 12, layout.y + 40)

        local yPos = layout.y + 60
        for symbol, holding in pairs(holdings) do
            if holding.quantity > 0.0001 then
                local nodeForStats = NodeMarket.getNodeBySymbol(symbol)
                local stats = nodeForStats and NodeMarket.getStats(nodeForStats)
                if stats and stats.price then
                    local currentValue = stats.price * holding.quantity
                    local changePct = holding.avgPrice > 0 and ((stats.price - holding.avgPrice) / holding.avgPrice) * 100 or 0
                    local changeColor = changePct >= 0 and Theme.colors.positive or Theme.colors.negative

                    Theme.setColor(Theme.colors.text)
                    love.graphics.print(string.format("%s: %.4f", symbol, holding.quantity), layout.x + 12, yPos)

                    Theme.setColor(changeColor)
                    love.graphics.print(string.format("Value: %s GC", formatPrice(currentValue)), layout.x + 120, yPos)

                    love.graphics.print(string.format("(%+.2f%%)", changePct), layout.x + 220, yPos)

                    yPos = yPos + 22
                end
            end
        end
    elseif self.activeBottomTab == "transactions" then
        local node = NodeMarket.getNodeBySymbol(self.selectedSymbol)
        local transactions = node and NodeMarket.getNodeTransactions(self.selectedSymbol) or {}
        Log.debug(string.format("ui.nodes.transactions - symbol=%s count=%d", tostring(self.selectedSymbol), #transactions))
        love.graphics.setFont(Theme.fonts.small)

        Theme.setColor(Theme.colors.textSecondary)
        love.graphics.print("TIME", layout.x + 12, layout.y + 40)
        love.graphics.print("TYPE", layout.x + 100, layout.y + 40)
        love.graphics.print("TRADER", layout.x + 160, layout.y + 40)
        love.graphics.print("AMOUNT", layout.x + 230, layout.y + 40)
        love.graphics.print("PRICE", layout.x + 320, layout.y + 40)
        love.graphics.print("VALUE", layout.x + 400, layout.y + 40)

        local yPos = layout.y + 58
        local maxRows = math.floor((layout.h - 80) / 16)
        local startIndex = math.max(1, #transactions - maxRows + 1)

        for i = #transactions, startIndex, -1 do
            local tx = transactions[i]
            if tx then
                Theme.setColor(Theme.colors.textSecondary)
                local timeStr = os.date("%H:%M:%S", tx.timestamp)
                love.graphics.print(timeStr, layout.x + 12, yPos)

                local typeColor = Theme.colors.text
                if tx.type == "BUY" or tx.type == "LIMIT_BUY" then
                    typeColor = Theme.colors.positive
                elseif tx.type == "SELL" or tx.type == "LIMIT_SELL" then
                    typeColor = Theme.colors.negative
                end
                Theme.setColor(typeColor)
                local displayType = tx.type:gsub("LIMIT_", "L.")
                love.graphics.print(displayType, layout.x + 100, yPos)

                Theme.setColor(tx.isPlayerTrade and Theme.colors.textHighlight or Theme.colors.textSecondary)
                local traderText = tx.isPlayerTrade and "PLAYER" or "AI"
                love.graphics.print(traderText, layout.x + 160, yPos)

                Theme.setColor(Theme.colors.text)
                love.graphics.print(string.format("%.4f", tx.quantity), layout.x + 230, yPos)
                love.graphics.print(formatPrice(tx.price), layout.x + 320, yPos)

                local totalValue = tx.quantity * tx.price
                love.graphics.print(formatPrice(totalValue), layout.x + 400, yPos)

                yPos = yPos + 16
                if yPos > layout.y + layout.h - 20 then break end
            end
        end

        if #transactions == 0 then
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.print("No recent trades", layout.x + 12, layout.y + 60)
        end
    end
end

function ChartView.draw(self, player, node, stats, layout)
    local mx, my = Viewport.getMousePosition()
    drawHeader(self, node, stats, {
        x = layout.header.x,
        y = layout.header.y,
        w = layout.header.w,
        h = layout.header.h,
        mx = mx,
        my = my,
    })

    drawGlobalStrip(layout.global)
    ChartRenderer.draw(self, node, layout.chart.x, layout.chart.y, layout.chart.w, layout.chart.h)
    drawBottomPanel(self, player, layout.bottom)
end

function ChartView.mousepressed(self, x, y, button)
    if button ~= 1 then return false end

    if self._yAxisLabels then
        for _, label in ipairs(self._yAxisLabels) do
            if Util.rectContains(x, y, label.x, label.y, label.w, label.h) then
                self._yScaleDragging = true
                return true
            end
        end
    end

    if self._chartRect and Util.rectContains(x, y, self._chartRect.x, self._chartRect.y, self._chartRect.w, self._chartRect.h) then
        self._xDragging = true
        self._yDragging = true
        return true
    end

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

function ChartView.mousemoved(self, x, y, dx, dy)
    if self._yScaleDragging then
        local scaleFactor = 1 + (dy * 0.01)
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
            self.xPanBars = (self.xPanBars or 0) - dx * barsPerPixel
        end
        return true
    end
    return false
end

function ChartView.wheelmoved(self, dx, dy)
    local mx, my = Viewport.getMousePosition()

    if self._chartRect and Util.rectContains(mx, my, self._chartRect.x, self._chartRect.y, self._chartRect.w, self._chartRect.h) then
        Log.debug("ui.nodes.zoom - inside chart area, applying zoom")

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

        local zoomFactor = 1 + (dy * 0.1)
        self.zoom = math.max(0.05, math.min(32.0, (self.zoom or 1.0) * zoomFactor))
        return true
    end

    if self._yAxisLabels then
        for _, label in ipairs(self._yAxisLabels) do
            if Util.rectContains(mx, my, label.x, label.y, label.w, label.h) then
                local zoomFactor = 1 + (dy * 0.1)
                self.yScale = math.max(0.1, math.min(20.0, (self.yScale or 1.0) * zoomFactor))
                return true
            end
        end
    end

    return false
end

return ChartView
