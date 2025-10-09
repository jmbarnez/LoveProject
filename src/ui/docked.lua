local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Quests = require("src.ui.quests")
local Nodes = require("src.ui.nodes")
local Window = require("src.ui.common.window")
local UITabs = require("src.ui.common.tabs")
local FurnacePanel = require("src.ui.docked.furnace_panel")
local ShopView = require("src.ui.docked.shop_view")
local DockedState = require("src.ui.docked.state")

-- Ship UI is standalone; do not require it here

local DockedUI = {}
DockedUI.state = DockedState.new()

local function get_docking(player)
    return player and player.components and player.components.docking_status
end

local function computeWindowBounds()
    local sw, sh = Viewport.getDimensions()
    local width = math.floor(math.min(sw - 80, math.max(900, sw * 0.65)))
    local height = math.floor(math.min(sh - 80, math.max(560, sh * 0.7)))
    local x = math.floor((sw - width) * 0.5)
    local y = math.floor((sh - height) * 0.5)
    return x, y, width, height
end

local function applyWindowBounds(window)
    if not window then return end
    local x, y, width, height = computeWindowBounds()
    window.x, window.y = x, y
    window.width, window.height = width, height
end

local function isFurnaceStation(state)
    return state.stationType == "ore_furnace_station"
end

function DockedUI.drawFurnaceContent(window, x, y, w, h)
    local state = DockedUI.state
    FurnacePanel.draw(state.furnaceState, state.player, x, y, w, h)
end

function DockedUI.handleFurnaceMousePressed(x, y, button)
    local state = DockedUI.state
    if not state.window then return false, false end

    if state.window:mousepressed(x, y, button) then
        return true, false
    end

    return FurnacePanel.mousepressed(state.furnaceState, state.player, x, y, button)
end

function DockedUI.init()
    local state = DockedUI.state
    if state.window then return end

    local x, y, width, height = computeWindowBounds()
    state.window = Window.new({
        title = "Station Services",
        x = x,
        y = y,
        width = width,
        height = height,
        useLoadPanelTheme = true,
        closable = true,
        draggable = true,
        resizable = false,
        panelId = "docked",
        drawContent = function(window, cx, cy, cw, ch)
            DockedUI.drawContent(window, cx, cy, cw, ch)
        end,
        onClose = function()
            if state.player then
                local PlayerSystem = require("src.systems.player")
                PlayerSystem.undock(state.player)
            end
        end
    })

    state.quests = Quests:new()
    state.nodes = Nodes:new()
    ShopView.init(state)
end

function DockedUI.show(player, station)
    local state = DockedUI.state
    DockedState.prepareForShow(state, player, station)

    -- Ensure UI is initialized before setting station
    if not state.window then
        DockedUI.init()
    end

    if state.window then
        applyWindowBounds(state.window)
        if isFurnaceStation(state) then
            local name = (station and station.components and station.components.station and station.components.station.name) or "Furnace Station"
            state.window.title = string.format("%s — Furnace Operations", name)
        else
            state.window.title = "Station Services"
        end
    end

    if state.quests then
        state.quests.station = station
    end
end

function DockedUI.hide()
    local state = DockedUI.state
    DockedState.markHidden(state)
    ShopView.hideContextMenu(state)
end

function DockedUI.isVisible()
    return DockedUI.state.visible
end

function DockedUI.isSearchActive()
    return DockedUI.state.searchActive
end

function DockedUI.draw(player)
    local state = DockedUI.state
    local docking = get_docking(player)
    if not state.visible or not player or not (docking and docking.docked) then return end
    if not state.window then DockedUI.init() end

    state.window.visible = state.visible
    state.window:draw()

    if state.activeTab == "Shop" and not isFurnaceStation(state) then
        local mx, my = Viewport.getMousePosition()
        ShopView.drawContextMenu(state, mx, my)
    end
end

function DockedUI.drawContent(window, x, y, w, h)
    local state = DockedUI.state
    local player = state.player
    local mx, my = Viewport.getMousePosition()

    if isFurnaceStation(state) then
        DockedUI.drawFurnaceContent(window, x, y, w, h)
        return
    end

    local pad = (Theme.ui and Theme.ui.contentPadding) or 12
    local mainTabY = y + ((Theme.ui and Theme.ui.contentPadding) or 8)
    local mainTabH = (Theme.ui and Theme.ui.buttonHeight) or 28
    DockedUI.drawMainTabs(x + pad, mainTabY, w - pad * 2, mainTabH)

    local contentY = mainTabY + mainTabH + ((Theme.ui and Theme.ui.buttonSpacing) or 8)
    local contentH = h - (contentY - y) - pad

    if state.activeTab == "Shop" then
        local shopContentY = contentY
        local shopContentH = h - (shopContentY - y) - pad

        ShopView.draw(state, x + pad, shopContentY, w - pad * 2, shopContentH, player, mx, my)

        if state.categoryDropdown then
            state.categoryDropdown:drawOptionsOnly(mx, my)
        end
    elseif state.activeTab == "Quests" and state.quests then
        state.quests:draw(player, x + pad, contentY, w - pad * 2, contentH)
    elseif state.activeTab == "Nodes" and state.nodes then
        state.nodes:draw(player, x + pad, contentY, w - pad * 2, contentH)
    end
end

function DockedUI.drawMainTabs(x, y, w, h)
    local state = DockedUI.state
    local res = UITabs.draw(x, y, w, h, state.tabs, state.activeTab)
    state._mainTabs = res.rects
end

function DockedUI.drawBuybackItems(x, y, w, h, player)
    return ShopView.drawBuybackItems(DockedUI.state, x, y, w, h, player)
end

function DockedUI.drawPlayerCargoForSale(x, y, w, h, player)
    return ShopView.drawPlayerCargo(DockedUI.state, x, y, w, h, player)
end

function DockedUI.drawShopItems(x, y, w, h, player)
    return ShopView.drawShopItems(DockedUI.state, x, y, w, h, player)
end

function DockedUI.purchaseItem(item, player, quantity)
    return ShopView.purchaseItem(DockedUI.state, item, player, quantity)
end

function DockedUI.sellItem(item, player, quantity)
    return ShopView.sellItem(DockedUI.state, item, player, quantity)
end

function DockedUI.mousepressed(x, y, button, player)
    local state = DockedUI.state
    if not state.visible then return false, false end
    if not state.window then return false, false end

    if player then
        state.player = player
    end
    local currentPlayer = state.player

    if isFurnaceStation(state) then
        return DockedUI.handleFurnaceMousePressed(x, y, button)
    end

    if state.window:mousepressed(x, y, button) then
        return true, false
    end

    if state._mainTabs then
        for _, tab in ipairs(state._mainTabs) do
            if x >= tab.x and x <= tab.x + tab.w and y >= tab.y and y <= tab.y + tab.h then
                state.activeTab = tab.name
                if state.activeTab ~= "Shop" then
                    state.searchActive = false
                    ShopView.hideContextMenu(state)
                end
                return true, false
            end
        end
    end

    if state.activeTab == "Shop" then
        return ShopView.mousepressed(state, x, y, button, currentPlayer)
    elseif state.activeTab == "Quests" and state.quests then
        return state.quests:mousepressed(currentPlayer, x, y, button)
    elseif state.activeTab == "Nodes" and state.nodes then
        return state.nodes:mousepressed(currentPlayer, x, y, button)
    end

    return false, false
end

function DockedUI.mousereleased(x, y, button, player)
    local state = DockedUI.state
    if not state.visible then return false, false end
    if not state.window then return false, false end

    if player then
        state.player = player
    end
    local currentPlayer = state.player

    if isFurnaceStation(state) then
        if state.window:mousereleased(x, y, button) then
            return true, false
        end
        return false, false
    end

    if state.window:mousereleased(x, y, button) then
        return true, false
    end

    if button == 1 and state._draggingScroll then
        state._draggingScroll = nil
        state._dragScrollOffsetY = nil
        return true, false
    end

    if state.activeTab == "Quests" and state.quests then
        return state.quests:mousereleased(currentPlayer, x, y, button)
    elseif state.activeTab == "Nodes" and state.nodes then
        return state.nodes:mousereleased(currentPlayer, x, y, button)
    end

    return false, false
end

function DockedUI.mousemoved(x, y, dx, dy, player)
    local state = DockedUI.state
    if not state.visible then return false, false end
    if not state.window then return false, false end

    if player then
        state.player = player
    end
    local currentPlayer = state.player

    if isFurnaceStation(state) then
        if state.window:mousemoved(x, y, dx, dy) then
            return true, false
        end
        return false, false
    end

    if state.window:mousemoved(x, y, dx, dy) then
        return true, false
    end

    if state._draggingScroll and state._shopScrollBar and state._shopMaxScroll then
        local sb = state._shopScrollBar
        local thumbH = sb.thumbH or 20
        local localY = y - sb.y - state._dragScrollOffsetY
        local pct = math.max(0, math.min(1, localY / (sb.h - thumbH)))
        state.shopScroll = pct * state._shopMaxScroll
        return true, false
    end

    if state.activeTab == "Shop" and state.categoryDropdown then
        state.categoryDropdown:mousemoved(x, y)
    end

    if state.activeTab == "Quests" and state.quests then
        return state.quests:mousemoved(currentPlayer, x, y, dx, dy)
    elseif state.activeTab == "Nodes" and state.nodes then
        return state.nodes:mousemoved(currentPlayer, x, y, dx, dy)
    end

    return false, false
end

function DockedUI.wheelmoved(dx, dy, player)
    local state = DockedUI.state
    if not state.visible then return false end
    if isFurnaceStation(state) then
        return false
    end
    if player then
        state.player = player
    end

    if state.activeTab == "Nodes" and state.nodes and state.nodes.wheelmoved then
        return state.nodes:wheelmoved(state.player, dx, dy)
    end
    return false
end

function DockedUI.keypressed(key, scancode, isrepeat, player)
    local state = DockedUI.state
    if not state.visible then return false end

    if player then
        state.player = player
    end
    local currentPlayer = state.player

    if isFurnaceStation(state) then
        return FurnacePanel.keypressed(state.furnaceState, key, currentPlayer)
    end

    if state.activeTab == "Shop" then
        local consumed, shouldClose = ShopView.keypressed(state, key, scancode, isrepeat, currentPlayer)
        if consumed ~= nil then
            return consumed, shouldClose or false
        end
    end

    if key == "escape" then
        return true, true
    end

    if state.activeTab == "Nodes" and state.nodes and state.nodes.keypressed then
        return state.nodes:keypressed(key)
    end

    return true, false
end

function DockedUI.textinput(text, player)
    local state = DockedUI.state
    if not state.visible then return false end

    if player then
        state.player = player
    end

    if isFurnaceStation(state) then
        return FurnacePanel.textinput(state.furnaceState, text)
    end

    if state.activeTab == "Shop" then
        local consumed = ShopView.textinput(state, text, player)
        if consumed ~= nil then
            return consumed
        end
    end

    if state.activeTab == "Nodes" and state.nodes and state.nodes.textinput then
        return state.nodes:textinput(text)
    end

    return false
end

function DockedUI.update(dt)
    local state = DockedUI.state
    if not state.visible then return end

    if state.activeTab == "Quests" and state.quests then
        state.quests:update(dt)
    elseif state.activeTab == "Nodes" and state.nodes then
        state.nodes:update(dt)
    end
end

return DockedUI
