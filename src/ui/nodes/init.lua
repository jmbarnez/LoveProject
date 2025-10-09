--[[
    Nodes UI Main Orchestrator
    
    Coordinates all Nodes UI modules and provides the main interface.
    Integrates with the panel registry system.
]]

local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local NodeMarket = require("src.systems.node_market")
local TechnicalIndicators = require("src.systems.technical_indicators")
local ChartRenderer = require("src.ui.nodes.chart_renderer")
local PortfolioManager = require("src.managers.portfolio")
local Window = require("src.ui.common.window")

-- Import all Nodes UI modules
local NodesState = require("src.ui.nodes.state")
local MarketHeader = require("src.ui.nodes.market_header")
local TradingUI = require("src.ui.nodes.trading_ui")
local InputHandler = require("src.ui.nodes.input_handler")

local Nodes = {}

function Nodes:new()
    local o = {}
    setmetatable(o, Nodes)
    Nodes.__index = Nodes
    
    -- Initialize state
    o.state = NodesState.new()
    
    -- Initialize window
    o.window = Window.new({
        title = "Node Market",
        width = 1000,
        height = 700,
        minWidth = 800,
        minHeight = 500,
        resizable = true
    })
    
    -- Initialize visibility
    o.visible = false
    
    return o
end

function Nodes:show()
    self.visible = true
    self.window:show()
    
    -- Update dropdown options
    MarketHeader.updateDropdownOptions(self, 200, 28)
end

function Nodes:hide()
    self.visible = false
    self.window:hide()
end

function Nodes:isVisible()
    return self.visible
end

function Nodes:draw(player)
    if not self.visible then return end
    
    -- Update window bounds
    local sw, sh = Viewport.getDimensions()
    local x, y = self.window.x, self.window.y
    local w, h = self.window.width, self.window.height
    
    -- Draw window
    self.window:draw()
    
    -- Get current node and stats
    local node = NodeMarket.getNode(self.state.selectedSymbol)
    local stats = node and TechnicalIndicators.getStats(node.symbol, self.state.range) or {}
    
    -- Draw header
    local headerH = 60
    MarketHeader.draw(self, node, stats, x, y, w, headerH, 0, 0) -- mx, my will be updated in input handler
    
    -- Draw chart
    local chartY = y + headerH
    local chartH = h - headerH - 200
    self:drawChart(node, stats, x, chartY, w, chartH)
    
    -- Draw trading interface
    TradingUI.draw(self, player, node, stats, x, y, w, h)
end

function Nodes:drawChart(node, stats, x, y, w, h)
    if not node then
        -- Draw no data message
        Theme.setColor(Theme.colors.textSecondary)
        Theme.setFont("medium")
        local text = "No market data available"
        local textW = Theme.fonts.medium:getWidth(text)
        local textH = Theme.fonts.medium:getHeight()
        local textX = x + (w - textW) * 0.5
        local textY = y + (h - textH) * 0.5
        love.graphics.print(text, textX, textY)
        return
    end
    
    -- Get market data
    local samples = NodeMarket.getMarketData(node.symbol, self.state.range)
    if not samples or #samples == 0 then
        -- Draw no data message
        Theme.setColor(Theme.colors.textSecondary)
        Theme.setFont("medium")
        local text = "No market data for " .. node.symbol
        local textW = Theme.fonts.medium:getWidth(text)
        local textH = Theme.fonts.medium:getHeight()
        local textX = x + (w - textW) * 0.5
        local textY = y + (h - textH) * 0.5
        love.graphics.print(text, textX, textY)
        return
    end
    
    -- Draw chart background
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Draw chart border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Draw chart using ChartRenderer
    ChartRenderer.draw(samples, x, y, w, h, {
        chartType = self.state.chartType,
        zoom = self.state.zoom,
        yScale = self.state.yScale,
        yOffset = self.state.yOffset,
        xPanBars = self.state.xPanBars,
        range = self.state.range
    })
end

function Nodes:update(dt)
    if not self.visible then return end
    
    -- Update market data
    local node = NodeMarket.getNode(self.state.selectedSymbol)
    if node then
        local prices = NodeMarket.getCurrentPrices(node.symbol)
        self.state:updateLastPrices(prices)
    end
    
    -- Update dropdown if needed
    if self.state.nodeDropdown then
        MarketHeader.updateDropdownOptions(self, 200, 28)
    end
end

function Nodes:mousepressed(player, x, y, button)
    if not self.visible then return false end
    
    -- Check if click is within window bounds
    if not self.window:isPointInside(x, y) then
        return false
    end
    
    return InputHandler.mousepressed(self, player, x, y, button)
end

function Nodes:mousereleased(player, x, y, button)
    if not self.visible then return false end
    
    return InputHandler.mousereleased(self, player, x, y, button)
end

function Nodes:mousemoved(player, x, y, dx, dy)
    if not self.visible then return false end
    
    return InputHandler.mousemoved(self, player, x, y, dx, dy)
end

function Nodes:wheelmoved(player, dx, dy)
    if not self.visible then return false end
    
    return InputHandler.wheelmoved(self, player, dx, dy)
end

function Nodes:keypressed(playerOrKey, maybeKey)
    if not self.visible then return false end
    
    return InputHandler.keypressed(self, playerOrKey, maybeKey)
end

function Nodes:textinput(text)
    if not self.visible then return false end
    
    return InputHandler.textinput(self, text)
end

function Nodes:resize(w, h)
    if self.window then
        self.window:resize(w, h)
    end
end

-- Backward compatibility methods
function Nodes:executeBuy(player)
    local amount = self.state.buyAmount
    if amount and tonumber(amount) and tonumber(amount) > 0 then
        local TradingEngine = require("src.ui.nodes.trading_engine")
        return TradingEngine.executeBuy(self.state, amount, self.state.orderType, self.state.limitPrice)
    end
    return false
end

function Nodes:executeSell(player)
    local amount = self.state.sellAmount
    if amount and tonumber(amount) and tonumber(amount) > 0 then
        local TradingEngine = require("src.ui.nodes.trading_engine")
        return TradingEngine.executeSell(self.state, amount, self.state.orderType, self.state.limitPrice)
    end
    return false
end

return Nodes
