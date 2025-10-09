local History = require("src.core.history")
local Dropdown = require("src.ui.common.dropdown")
local NodeMarket = require("src.systems.node_market")

local State = {}

local function pushInitialHistory(node)
    if not node.history then
        return
    end

    node.history:push({
        range = node.range,
        zoom = node.zoom,
        yScale = node.yScale,
        yOffset = node.yOffset,
        xPanBars = node.xPanBars,
        selectedSymbol = node.selectedSymbol,
        chartType = node.chartType,
    })
end

local function createDropdown(node)
    return Dropdown.new({
        x = 0,
        y = 0,
        width = 200,
        optionHeight = 28,
        options = {},
        selectedIndex = 1,
        onSelect = function(index)
            local nodes = NodeMarket.getNodes()
            local selectedNode = nodes and nodes[index]
            if not selectedNode then
                return
            end

            if node.selectedSymbol == selectedNode.symbol then
                return
            end

            if node.nodeViewStates then
                node.nodeViewStates[node.selectedSymbol] = {
                    yScale = node.yScale,
                    yOffset = node.yOffset,
                    xPanBars = node.xPanBars,
                    zoom = node.zoom,
                }
            end

            node.selectedSymbol = selectedNode.symbol

            local savedState = node.nodeViewStates and node.nodeViewStates[node.selectedSymbol]
            if savedState then
                node.yScale = savedState.yScale
                node.yOffset = savedState.yOffset
                node.xPanBars = savedState.xPanBars
                node.zoom = savedState.zoom
            else
                node.yScale = 1.0
                node.yOffset = 0.0
                node.xPanBars = 0
                node.zoom = 1.0
            end
        end,
    })
end

function State.initialize(node)
    node.selectedSymbol = node.selectedSymbol or "AST"
    node.range = node.range or "1m"
    node.chartType = node.chartType or "candle"
    node.zoom = node.zoom or 1.0
    node.yScale = node.yScale or 1.0
    node.yOffset = node.yOffset or 0.0
    node.xPanBars = node.xPanBars or 0
    node._xDragging = false
    node._yDragging = false
    node._yScaleDragging = false
    node.lastPrices = node.lastPrices or {}
    node.intervalSeconds = node.intervalSeconds or 60
    node.activeBottomTab = node.activeBottomTab or "portfolio"
    node.history = node.history or History.new(200)
    node.nodeViewStates = node.nodeViewStates or {}

    node.tradingMode = node.tradingMode or "buy"
    node.buyAmount = node.buyAmount or ""
    node.sellAmount = node.sellAmount or ""
    node.buyInputActive = node.buyInputActive or false
    node.sellInputActive = node.sellInputActive or false
    node.orderType = node.orderType or "market"
    node.limitPrice = node.limitPrice or ""
    node.limitPriceInputActive = node.limitPriceInputActive or false

    node.nodeDropdown = node.nodeDropdown or createDropdown(node)

    pushInitialHistory(node)
end

return State
