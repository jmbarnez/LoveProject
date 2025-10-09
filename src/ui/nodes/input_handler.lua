--[[
    Nodes Input Handler
    
    Handles all input events for the Nodes UI including:
    - Mouse interactions (clicks, drags, wheel)
    - Keyboard input
    - Text input
    - Chart interactions
]]

local Theme = require("src.core.theme")
local MarketHeader = require("src.ui.nodes.market_header")
local TradingUI = require("src.ui.nodes.trading_ui")
local TradingEngine = require("src.ui.nodes.trading_engine")

local InputHandler = {}

function InputHandler.mousepressed(self, player, x, y, button)
    if button ~= 1 then return false end
    
    local mx, my = x, y
    
    -- Handle trading tab clicks
    local tradingY = self.window.y + self.window.height - 200
    if TradingUI.handleTradingTabClick(self, mx, my, self.window.x, tradingY, self.window.width) then
        return true
    end
    
    -- Handle range selector clicks
    local headerH = 60
    local rangeY = self.window.y + headerH - 24
    if MarketHeader.handleRangeClick(self, mx, my, self.window.x, rangeY, 200, 20) then
        return true
    end
    
    -- Handle dropdown clicks
    if MarketHeader.handleDropdownClick(self, mx, my) then
        return true
    end
    
    -- Handle order type selector clicks
    local tradingContentY = tradingY + 30
    local orderTypeX = self.window.x + 12 + self.window.width * 0.35
    local orderTypeY = tradingContentY + 12
    if TradingUI.handleOrderTypeClick(self, mx, my, orderTypeX, orderTypeY, self.window.width * 0.25) then
        return true
    end
    
    -- Handle execute button clicks
    local buttonY = tradingContentY + 12 + 28 + 8 + 60 + 8
    local buttonW = 120
    local buttonX = self.window.x + self.window.width - buttonW - 12
    local node = require("src.systems.node_market").getNode(self.state.selectedSymbol)
    if TradingUI.handleExecuteClick(self, mx, my, buttonX, buttonY, buttonW, 32, node) then
        return true
    end
    
    -- Handle chart interactions
    local chartY = self.window.y + 60
    local chartH = self.window.height - 260
    if InputHandler.handleChartClick(self, mx, my, self.window.x, chartY, self.window.width, chartH) then
        return true
    end
    
    return false
end

function InputHandler.mousereleased(self, player, x, y, button)
    if button ~= 1 then return false end
    
    local mx, my = x, y
    
    -- Handle dropdown release
    if MarketHeader.handleDropdownRelease(self, mx, my) then
        return true
    end
    
    -- Stop dragging
    if self.state:isDragging() then
        self.state:setDragging("x", false)
        self.state:setDragging("y", false)
        self.state:setDragging("yScale", false)
        return true
    end
    
    return false
end

function InputHandler.mousemoved(self, player, x, y, dx, dy)
    local mx, my = x, y
    
    -- Handle dropdown mouse move
    if MarketHeader.handleDropdownMove(self, mx, my, dx, dy) then
        return true
    end
    
    -- Handle chart dragging
    if self.state:isDragging() then
        local chartY = self.window.y + 60
        local chartH = self.window.height - 260
        
        if self.state._xDragging then
            -- Pan horizontally
            local panSensitivity = 2.0
            self.state.xPanBars = self.state.xPanBars - dx * panSensitivity
            self.state:pushHistory()
        elseif self.state._yDragging then
            -- Pan vertically
            local panSensitivity = 0.01
            self.state.yOffset = self.state.yOffset + dy * panSensitivity
            self.state:pushHistory()
        elseif self.state._yScaleDragging then
            -- Scale vertically
            local scaleSensitivity = 0.01
            local scaleFactor = 1.0 - dy * scaleSensitivity
            self.state.yScale = math.max(0.1, math.min(10.0, self.state.yScale * scaleFactor))
            self.state:pushHistory()
        end
        
        return true
    end
    
    return false
end

function InputHandler.wheelmoved(self, player, dx, dy)
    -- Handle zoom
    local zoomSensitivity = 0.1
    local zoomFactor = 1.0 + dy * zoomSensitivity
    self.state.zoom = math.max(0.1, math.min(5.0, self.state.zoom * zoomFactor))
    self.state:pushHistory()
    
    return true
end

function InputHandler.keypressed(self, playerOrKey, maybeKey)
    local key = playerOrKey
    if type(playerOrKey) == "table" then
        key = maybeKey
    end
    
    -- Handle input focus switching
    if key == "tab" then
        if self.state.tradingMode == "buy" then
            if self.state.buyInputActive then
                self.state:setInputActive("buy", false)
                if self.state.orderType == "limit" then
                    self.state:setInputActive("limit", true)
                end
            else
                self.state:setInputActive("buy", true)
            end
        else
            if self.state.sellInputActive then
                self.state:setInputActive("sell", false)
                if self.state.orderType == "limit" then
                    self.state:setInputActive("limit", true)
                end
            else
                self.state:setInputActive("sell", true)
            end
        end
        return true
    end
    
    -- Handle enter key for execution
    if key == "return" or key == "kpenter" then
        local node = require("src.systems.node_market").getNode(self.state.selectedSymbol)
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
        return true
    end
    
    -- Handle escape to clear inputs
    if key == "escape" then
        if self.state:isInputActive() then
            self.state:setInputActive("buy", false)
            self.state:setInputActive("sell", false)
            self.state:setInputActive("limit", false)
        else
            -- Clear current input
            if self.state.tradingMode == "buy" then
                self.state.buyAmount = ""
            else
                self.state.sellAmount = ""
            end
            self.state.limitPrice = ""
        end
        return true
    end
    
    -- Handle undo/redo
    if key == "z" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            -- Redo
            if self.state:redo() then
                return true
            end
        else
            -- Undo
            if self.state:undo() then
                return true
            end
        end
    end
    
    return false
end

function InputHandler.textinput(self, text)
    if not self.state:isInputActive() then
        return false
    end
    
    -- Handle text input based on active input
    if self.state.buyInputActive then
        if text:match("[%d%.]") then
            self.state.buyAmount = self.state.buyAmount .. text
        end
    elseif self.state.sellInputActive then
        if text:match("[%d%.]") then
            self.state.sellAmount = self.state.sellAmount .. text
        end
    elseif self.state.limitPriceInputActive then
        if text:match("[%d%.]") then
            self.state.limitPrice = self.state.limitPrice .. text
        end
    end
    
    return true
end

function InputHandler.handleChartClick(self, mx, my, x, y, w, h)
    -- Check if click is within chart area
    if mx < x or mx >= x + w or my < y or my >= y + h then
        return false
    end
    
    -- Determine click area for different interactions
    local leftArea = w * 0.1
    local rightArea = w * 0.9
    local topArea = h * 0.1
    local bottomArea = h * 0.9
    
    local relativeX = mx - x
    local relativeY = my - y
    
    -- Left area: horizontal pan
    if relativeX < leftArea then
        self.state:setDragging("x", true)
        return true
    end
    
    -- Right area: vertical scale
    if relativeX > rightArea then
        self.state:setDragging("yScale", true)
        return true
    end
    
    -- Top/bottom areas: vertical pan
    if relativeY < topArea or relativeY > bottomArea then
        self.state:setDragging("y", true)
        return true
    end
    
    -- Center area: no specific action, but mark as handled
    return true
end

function InputHandler.handleBackspace(self)
    if not self.state:isInputActive() then
        return false
    end
    
    -- Handle backspace based on active input
    if self.state.buyInputActive then
        if #self.state.buyAmount > 0 then
            self.state.buyAmount = self.state.buyAmount:sub(1, -2)
        end
    elseif self.state.sellInputActive then
        if #self.state.sellAmount > 0 then
            self.state.sellAmount = self.state.sellAmount:sub(1, -2)
        end
    elseif self.state.limitPriceInputActive then
        if #self.state.limitPrice > 0 then
            self.state.limitPrice = self.state.limitPrice:sub(1, -2)
        end
    end
    
    return true
end

return InputHandler
