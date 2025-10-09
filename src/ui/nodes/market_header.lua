--[[
    Nodes Market Header
    
    Handles rendering of market header including:
    - Node selection dropdown
    - Price display
    - Market statistics
    - Range selection
]]

local Theme = require("src.core.theme")
local NodeMarket = require("src.systems.node_market")
local PortfolioManager = require("src.managers.portfolio")
local TradingEngine = require("src.ui.nodes.trading_engine")

local MarketHeader = {}

function MarketHeader.draw(self, node, stats, x, y, w, h, mx, my)
    local headerH = 60
    local pad = 8
    
    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, headerH)
    
    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, headerH)
    
    -- Node dropdown
    local dropdownX = x + pad
    local dropdownY = y + pad
    local dropdownW = 200
    local dropdownH = 28
    
    -- Update dropdown options if needed
    MarketHeader.updateDropdownOptions(self, dropdownW, dropdownH)
    
    -- Position dropdown
    self.state.nodeDropdown.x = dropdownX
    self.state.nodeDropdown.y = dropdownY
    self.state.nodeDropdown.width = dropdownW
    self.state.nodeDropdown.height = dropdownH
    
    -- Draw dropdown
    self.state.nodeDropdown:draw()
    
    -- Price display
    local priceX = dropdownX + dropdownW + pad * 2
    local priceY = y + pad
    local priceW = 200
    local priceH = 28
    
    MarketHeader.drawPriceDisplay(node, priceX, priceY, priceW, priceH)
    
    -- Market stats
    local statsX = priceX + priceW + pad * 2
    local statsY = y + pad
    local statsW = w - statsX - pad
    local statsH = 28
    
    MarketHeader.drawMarketStats(node, stats, statsX, statsY, statsW, statsH)
    
    -- Range selector
    local rangeY = y + headerH - 24
    local rangeX = x + pad
    local rangeW = 200
    local rangeH = 20
    
    MarketHeader.drawRangeSelector(self, rangeX, rangeY, rangeW, rangeH, mx, my)
end

function MarketHeader.updateDropdownOptions(self, w, h)
    local nodes = NodeMarket.getAvailableNodes()
    local options = {}
    
    for i, node in ipairs(nodes) do
        table.insert(options, {
            text = node.symbol,
            symbol = node.symbol,
            value = node
        })
    end
    
    self.state.nodeDropdown.options = options
    self.state.nodeDropdown.width = w
    self.state.nodeDropdown.height = h
    
    -- Update selected index
    for i, option in ipairs(options) do
        if option.symbol == self.state.selectedSymbol then
            self.state.nodeDropdown.selectedIndex = i
            break
        end
    end
end

function MarketHeader.drawPriceDisplay(node, x, y, w, h)
    if not node then return end
    
    -- Background
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Price text
    local priceText = TradingEngine.formatPrice(node.price)
    local changeText = ""
    local changeColor = Theme.colors.text
    
    if node.change and node.changePercent then
        local sign = node.change >= 0 and "+" or ""
        changeText = string.format("%s%.2f (%.2f%%)", sign, node.change, node.changePercent)
        changeColor = node.change >= 0 and Theme.colors.success or Theme.colors.danger
    end
    
    -- Main price
    Theme.setFont("medium")
    Theme.setColor(Theme.colors.text)
    love.graphics.print(priceText, x + 8, y + 4)
    
    -- Change
    if changeText ~= "" then
        Theme.setFont("small")
        Theme.setColor(changeColor)
        love.graphics.print(changeText, x + 8, y + 18)
    end
end

function MarketHeader.drawMarketStats(node, stats, x, y, w, h)
    if not node or not stats then return end
    
    -- Background
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    local textY = y + 6
    local lineHeight = 12
    local col1X = x + 8
    local col2X = x + w * 0.3
    local col3X = x + w * 0.6
    
    Theme.setFont("small")
    
    -- Volume
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Volume:", col1X, textY)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(TradingEngine.formatPrice(stats.volume or 0), col1X + 50, textY)
    
    -- Market Cap
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Market Cap:", col2X, textY)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(TradingEngine.formatMarketCap(stats.marketCap or 0), col2X + 60, textY)
    
    -- High/Low
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("H/L:", col3X, textY)
    local highLow = string.format("%.2f/%.2f", stats.high or 0, stats.low or 0)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(highLow, col3X + 25, textY)
    
    textY = textY + lineHeight
    
    -- 24h Change
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("24h Change:", col1X, textY)
    local change24h = stats.change24h or 0
    local change24hColor = change24h >= 0 and Theme.colors.success or Theme.colors.danger
    Theme.setColor(change24hColor)
    love.graphics.print(string.format("%+.2f%%", change24h), col1X + 70, textY)
    
    -- Portfolio value
    local portfolio = PortfolioManager.getPortfolio()
    local holdings = portfolio.holdings[node.symbol] or 0
    local portfolioValue = holdings * node.price
    
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Holdings:", col2X, textY)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(string.format("%.0f (%.2f)", holdings, portfolioValue), col2X + 60, textY)
end

function MarketHeader.drawRangeSelector(self, x, y, w, h, mx, my)
    local ranges = {"1m", "5m", "15m", "1h", "4h", "1d"}
    local buttonW = w / #ranges
    local buttonH = h
    
    for i, range in ipairs(ranges) do
        local buttonX = x + (i - 1) * buttonW
        local buttonY = y
        local isHover = mx >= buttonX and mx < buttonX + buttonW and my >= buttonY and my < buttonY + buttonH
        local isSelected = self.state.range == range
        
        -- Button background
        local bgColor = isSelected and Theme.colors.accent or (isHover and Theme.colors.bg3 or Theme.colors.bg2)
        Theme.setColor(bgColor)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH)
        
        -- Button border
        local borderColor = isSelected and Theme.colors.borderBright or Theme.colors.border
        Theme.setColor(borderColor)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH)
        
        -- Button text
        local textColor = isSelected and Theme.colors.textHighlight or Theme.colors.text
        Theme.setColor(textColor)
        Theme.setFont("small")
        local textW = Theme.fonts.small:getWidth(range)
        local textH = Theme.fonts.small:getHeight()
        local textX = buttonX + (buttonW - textW) * 0.5
        local textY = buttonY + (buttonH - textH) * 0.5
        love.graphics.print(range, textX, textY)
    end
end

function MarketHeader.handleRangeClick(self, mx, my, x, y, w, h)
    local ranges = {"1m", "5m", "15m", "1h", "4h", "1d"}
    local buttonW = w / #ranges
    local buttonH = h
    
    for i, range in ipairs(ranges) do
        local buttonX = x + (i - 1) * buttonW
        local buttonY = y
        
        if mx >= buttonX and mx < buttonX + buttonW and my >= buttonY and my < buttonY + buttonH then
            if self.state.range ~= range then
                self.state.range = range
                self.state:pushHistory()
                return true
            end
        end
    end
    
    return false
end

function MarketHeader.handleDropdownClick(self, mx, my)
    return self.state.nodeDropdown:mousepressed(mx, my, 1)
end

function MarketHeader.handleDropdownRelease(self, mx, my)
    return self.state.nodeDropdown:mousereleased(mx, my, 1)
end

function MarketHeader.handleDropdownMove(self, mx, my, dx, dy)
    return self.state.nodeDropdown:mousemoved(mx, my, dx, dy)
end

return MarketHeader
