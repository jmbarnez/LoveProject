--[[
    Nodes UI State Management
    
    Manages all state for the Nodes UI including:
    - Node selection and view states
    - Trading interface state
    - Chart view parameters
    - Input states
]]

local History = require("src.core.history")
local Dropdown = require("src.ui.common.dropdown")

local NodesState = {}

function NodesState.new()
    local state = {
        -- Node selection and view
        selectedSymbol = "AST", -- Default node
        range = "1m",
        chartType = "candle",
        zoom = 1.0,
        yScale = 1.0,
        yOffset = 0.0,
        xPanBars = 0,
        
        -- Interaction states
        _xDragging = false,
        _yDragging = false,
        _yScaleDragging = false,
        
        -- Market data
        lastPrices = {},
        intervalSeconds = 60,
        
        -- UI state
        activeBottomTab = "portfolio",
        nodeViewStates = {}, -- Store view state per node
        
        -- Trading interface state
        tradingMode = "buy", -- "buy" or "sell"
        buyAmount = "",
        sellAmount = "",
        buyInputActive = false,
        sellInputActive = false,
        orderType = "market", -- "market" or "limit"
        limitPrice = "",
        limitPriceInputActive = false,
        
        -- History for undo/redo
        history = History.new(200),
        
        -- Node dropdown
        nodeDropdown = nil
    }
    
    -- Initialize node dropdown
    state.nodeDropdown = Dropdown.new({
        x = 0,
        y = 0,
        width = 200,
        optionHeight = 28,
        options = {},
        selectedIndex = 1,
        onSelect = function(index, option)
            NodesState.switchNode(state, option.symbol)
        end
    })
    
    -- Push initial view state
    if state.history then
        state.history:push({
            range = state.range,
            zoom = state.zoom,
            yScale = state.yScale,
            yOffset = state.yOffset,
            xPanBars = state.xPanBars,
            selectedSymbol = state.selectedSymbol,
            chartType = state.chartType,
        })
    end
    
    return state
end

function NodesState.switchNode(state, newSymbol)
    -- Only update if we're actually changing nodes
    if state.selectedSymbol ~= newSymbol then
        -- Save current node's view state
        if state.nodeViewStates then
            state.nodeViewStates[state.selectedSymbol] = {
                yScale = state.yScale,
                yOffset = state.yOffset,
                xPanBars = state.xPanBars,
                zoom = state.zoom
            }
        end

        -- Update to new node
        state.selectedSymbol = newSymbol

        -- Restore new node's view state or reset to defaults
        local savedState = state.nodeViewStates and state.nodeViewStates[state.selectedSymbol]
        if savedState then
            state.yScale = savedState.yScale
            state.yOffset = savedState.yOffset
            state.xPanBars = savedState.xPanBars
            state.zoom = savedState.zoom
        else
            -- Reset to default view for new node
            state.yScale = 1.0
            state.yOffset = 0.0
            state.xPanBars = 0
            state.zoom = 1.0
        end
    end
end

function NodesState.setTradingMode(state, mode)
    state.tradingMode = mode
end

function NodesState.setBuyAmount(state, amount)
    state.buyAmount = amount
end

function NodesState.setSellAmount(state, amount)
    state.sellAmount = amount
end

function NodesState.setOrderType(state, orderType)
    state.orderType = orderType
end

function NodesState.setLimitPrice(state, price)
    state.limitPrice = price
end

function NodesState.setInputActive(state, inputType, active)
    if inputType == "buy" then
        state.buyInputActive = active
    elseif inputType == "sell" then
        state.sellInputActive = active
    elseif inputType == "limit" then
        state.limitPriceInputActive = active
    end
end

function NodesState.isInputActive(state)
    return state.buyInputActive or state.sellInputActive or state.limitPriceInputActive
end

function NodesState.setChartView(state, zoom, yScale, yOffset, xPanBars)
    state.zoom = zoom or state.zoom
    state.yScale = yScale or state.yScale
    state.yOffset = yOffset or state.yOffset
    state.xPanBars = xPanBars or state.xPanBars
end

function NodesState.setDragging(state, type, dragging)
    if type == "x" then
        state._xDragging = dragging
    elseif type == "y" then
        state._yDragging = dragging
    elseif type == "yScale" then
        state._yScaleDragging = dragging
    end
end

function NodesState.isDragging(state)
    return state._xDragging or state._yDragging or state._yScaleDragging
end

function NodesState.setActiveTab(state, tab)
    state.activeBottomTab = tab
end

function NodesState.updateLastPrices(state, prices)
    state.lastPrices = prices or {}
end

function NodesState.pushHistory(state)
    if state.history then
        state.history:push({
            range = state.range,
            zoom = state.zoom,
            yScale = state.yScale,
            yOffset = state.yOffset,
            xPanBars = state.xPanBars,
            selectedSymbol = state.selectedSymbol,
            chartType = state.chartType,
        })
    end
end

function NodesState.undo(state)
    if state.history then
        local prev = state.history:undo()
        if prev then
            state.range = prev.range
            state.zoom = prev.zoom
            state.yScale = prev.yScale
            state.yOffset = prev.yOffset
            state.xPanBars = prev.xPanBars
            state.selectedSymbol = prev.selectedSymbol
            state.chartType = prev.chartType
            return true
        end
    end
    return false
end

function NodesState.redo(state)
    if state.history then
        local next = state.history:redo()
        if next then
            state.range = next.range
            state.zoom = next.zoom
            state.yScale = next.yScale
            state.yOffset = next.yOffset
            state.xPanBars = next.xPanBars
            state.selectedSymbol = next.selectedSymbol
            state.chartType = next.chartType
            return true
        end
    end
    return false
end

return NodesState
