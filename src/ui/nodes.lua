local NodeMarket = require("src.systems.node_market")
local ChartAnimations = require("src.systems.chart_animations")
local PortfolioManager = require("src.managers.portfolio")
local ChartView = require("src.ui.nodes.chart_view")
local TradePanel = require("src.ui.nodes.trade_panel")
local State = require("src.ui.nodes.state")

local Nodes = {}
Nodes.__index = Nodes

local function buildLayout(x, y, w, h)
    local headerH = 56
    local globalStripH = 18
    local bottomPanelH = 250
    local margin = 6
    local tradingW = 300
    local tradingH = 240

    local chartW = w - margin * 2
    local chartH = h - headerH - globalStripH - bottomPanelH - margin * 5
    local chartX = x + margin
    local chartY = y + headerH + globalStripH + margin * 2

    local bottomPanelW = chartW - tradingW - margin
    local bottomPanelX = chartX
    local bottomPanelY = chartY + chartH + margin

    local tradingX = bottomPanelX + bottomPanelW + margin
    local tradingY = bottomPanelY

    return {
        header = {
            x = x + margin,
            y = y + margin,
            w = w - margin * 2,
            h = headerH,
        },
        global = {
            x = x + margin,
            y = y + headerH + margin,
            w = w - margin * 2,
            h = globalStripH,
        },
        chart = {
            x = chartX,
            y = chartY,
            w = chartW,
            h = chartH,
        },
        bottom = {
            x = bottomPanelX,
            y = bottomPanelY,
            w = bottomPanelW,
            h = bottomPanelH,
        },
        trading = {
            x = tradingX,
            y = tradingY,
            w = tradingW,
            h = tradingH,
        },
    }
end

function Nodes:new()
    local instance = setmetatable({}, Nodes)
    State.initialize(instance)
    return instance
end

function Nodes:draw(player, x, y, w, h)
    NodeMarket.init()
    PortfolioManager.init()

    local nodes = NodeMarket.getNodes()
    if not nodes or #nodes == 0 then
        return
    end

    if not self.selectedSymbol then
        self.selectedSymbol = nodes[1].symbol
    end

    local node = NodeMarket.getNodeBySymbol(self.selectedSymbol)
    if not node then
        return
    end

    local stats = NodeMarket.getStats(node)
    if not stats then
        return
    end

    local layout = buildLayout(x, y, w, h)

    ChartView.draw(self, player, node, stats, layout)
    TradePanel.draw(self, player, node, stats, layout.trading)
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
    if TradePanel.mousepressed(self, player, x, y, button) then
        return true
    end

    if self.nodeDropdown and self.nodeDropdown:mousepressed(x, y, button) then
        return true
    end

    return ChartView.mousepressed(self, x, y, button)
end

function Nodes:mousereleased(player, x, y, button)
    self._xDragging = false
    self._yDragging = false
    self._yScaleDragging = false
    return false
end

function Nodes:mousemoved(player, x, y, dx, dy)
    if ChartView.mousemoved(self, x, y, dx, dy) then
        return true
    end
    return false
end

function Nodes:wheelmoved(player, dx, dy)
    if ChartView.wheelmoved(self, dx, dy) then
        return true
    end
    return false
end

function Nodes:textinput(text)
    if TradePanel.textinput(self, text) then
        return true
    end
    return false
end

function Nodes:keypressed(playerOrKey, maybeKey)
    local player, key
    if maybeKey == nil then
        player = nil
        key = playerOrKey
    else
        player = playerOrKey
        key = maybeKey
    end

    if not key then
        return false
    end

    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if ctrl and self.history then
        if key == "z" then
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
        elseif key == "y" then
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
    end

    if TradePanel.keypressed(self, player, key) then
        return true
    end

    return false
end

function Nodes:executeBuy(player)
    return TradePanel.executeBuy(self, player)
end

function Nodes:executeSell(player)
    return TradePanel.executeSell(self, player)
end

return Nodes
