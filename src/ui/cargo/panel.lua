local Viewport = require("src.core.viewport")
local PlayerRef = require("src.core.player_ref")
local Window = require("src.ui.common.window")
local CargoState = require("src.ui.cargo.state")
local StateUtils = require("src.ui.cargo.state_utils")
local Render = require("src.ui.cargo.render")
local Items = require("src.ui.cargo.items")
local ContextMenu = require("src.ui.cargo.context_menu")
local Actions = require("src.ui.cargo.actions")

local Cargo = CargoState.get()

local function getCurrentPlayer()
    return PlayerRef.get and PlayerRef.get() or nil
end

local function setSearchActive(active)
    CargoState.setSearchActive(active)
end

function Cargo.clearSearchFocus()
    CargoState.clearSearchFocus()
end

function Cargo.isSearchInputActive()
    return CargoState.isSearchInputActive()
end

function Cargo.init()
    Cargo.window = Window.new({
        title = "Cargo",
        width = 520,
        height = 400,
        minWidth = 300,
        minHeight = 200,
        useLoadPanelTheme = true,
        draggable = true,
        closable = true,
        drawContent = Cargo.drawContent,
        onClose = function()
            Cargo.visible = false
            setSearchActive(false)
            local Sound = require("src.core.sound")
            Sound.triggerEvent("ui_button_click")
        end
    })
end

function Cargo.getRect()
    if not Cargo.window then return nil end
    return { x = Cargo.window.x, y = Cargo.window.y, w = Cargo.window.width, h = Cargo.window.height }
end

function Cargo.refresh()
    Cargo.hoveredItem = nil
    Cargo.hoverTimer = 0
    ContextMenu.hide(Cargo)

    local TooltipManager = require("src.ui.tooltip_manager")
    TooltipManager.clearTooltip()

    local player = getCurrentPlayer()
    Cargo._cargoSnapshot = StateUtils.snapshot(player)
end

function Cargo.draw()
    if not Cargo.visible then return end
    if not Cargo.window then Cargo.init() end

    local ok, UIManager = pcall(require, "src.core.ui_manager")
    if ok and UIManager and UIManager.state and UIManager.state.cargo then
        UIManager.state.cargo.open = Cargo.visible
    end

    Cargo.window.visible = Cargo.visible
    Cargo.window:draw()
end

function Cargo.drawContent(window, x, y, w, h)
    local player = getCurrentPlayer()
    if not player then return end

    local currentSnapshot = StateUtils.snapshot(player)
    if StateUtils.hasChanged(Cargo._cargoSnapshot, currentSnapshot) then
        Cargo._cargoSnapshot = currentSnapshot
        Cargo.hoveredItem = nil
        Cargo.hoverTimer = 0
        ContextMenu.hide(Cargo)
    end

    Render.drawPanel(Cargo, player, x, y, w, h)

    if Cargo.contextMenu.visible then
        ContextMenu.draw(Cargo)
    end
end

function Cargo.mousepressed(x, y, button)
    if not Cargo.visible then return false end
    if not Cargo.window then Cargo.init() end

    if Cargo.window:mousepressed(x, y, button) then
        return true
    end

    local player = getCurrentPlayer()
    if not player then return false end

    local mx, my = Viewport.getMousePosition()

    if button == 1 then
        local searchRect = Cargo._searchRect
        if searchRect and mx >= searchRect.x and mx <= searchRect.x + searchRect.w and my >= searchRect.y and my <= searchRect.y + searchRect.h then
            setSearchActive(true)
            ContextMenu.hide(Cargo)
            return true
        end

        local sortRect = Cargo._sortRect
        if sortRect and mx >= sortRect.x and mx <= sortRect.x + sortRect.w and my >= sortRect.y and my <= sortRect.y + sortRect.h then
            if love.keyboard and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
                Cargo.sortOrder = (Cargo.sortOrder == "asc") and "desc" or "asc"
            else
                local sortFields = {"name", "type", "rarity", "value", "quantity"}
                local currentIndex = 1
                for i, field in ipairs(sortFields) do
                    if field == Cargo.sortBy then
                        currentIndex = i
                        break
                    end
                end
                Cargo.sortBy = sortFields[(currentIndex % #sortFields) + 1]
            end
            ContextMenu.hide(Cargo)
            return true
        end
    end

    if button ~= 1 then
        setSearchActive(false)
    end

    if ContextMenu.handleMousePress(Cargo, mx, my, button, player) then
        return true
    end

    if button == 2 then
        setSearchActive(false)
        local item, index = Render.getItemAtPosition(Cargo._slotRects, x, y)
        if item and ContextMenu.showForItem(Cargo, item, index, mx, my) then
            return true
        else
            ContextMenu.hide(Cargo)
        end
        return false
    end

    if button == 1 then
        setSearchActive(false)
        local item = select(1, Render.getItemAtPosition(Cargo._slotRects, x, y))
        if item then
            local def = Items.getItemDefinition(item)
            if def and (def.consumable or def.type == "consumable") then
                if Actions.useItem(player, item.id) then
                    return true
                end
            else
                local Sound = require("src.core.sound")
                Sound.playSFX("button_click")

                local Notifications = require("src.ui.notifications")
                Notifications.add("Nothing happens", "info")
                return true
            end
        end
    end

    return false
end

function Cargo.mousereleased(x, y, button)
    if not Cargo.visible then return false end
    if not Cargo.window then return false end
    return Cargo.window:mousereleased(x, y, button)
end

function Cargo.mousemoved(x, y, dx, dy)
    if not Cargo.visible then return false end
    if not Cargo.window then return false end
    return Cargo.window:mousemoved(x, y, dx, dy)
end

function Cargo.wheelmoved(x, y, dx, dy)
    if not Cargo.visible then return false end
    if not Cargo.window then return false end
    if not Cargo.window:containsPoint(x, y) then return false end

    local scrollSpeed = 40
    Cargo.scroll = Cargo.scroll - dy * scrollSpeed
    Cargo.scroll = math.max(0, math.min(Cargo.scroll, math.max(0, Cargo._scrollMax)))
    if Cargo.scroll ~= Cargo.scroll then Cargo.scroll = 0 end
    return true
end

function Cargo.update(dt)
    if not Cargo.visible then
        setSearchActive(false)
        local TooltipManager = require("src.ui.tooltip_manager")
        TooltipManager.clearTooltip()
        return
    end

    if Cargo.hoveredItem then
        local mx, my = Viewport.getMousePosition()
        local stillHovering = false
        if Cargo._slotRects then
            for _, slot in ipairs(Cargo._slotRects) do
                if mx >= slot.x and mx <= slot.x + slot.w and my >= slot.y and my <= slot.y + slot.h then
                    stillHovering = true
                    break
                end
            end
        end
        if not stillHovering then
            Cargo.hoveredItem = nil
            Cargo.hoverTimer = 0
        end
    end
end

function Cargo.keypressed(key)
    if not Cargo.visible then return false end

    if Cargo._searchInputActive then
        if key == "escape" then
            setSearchActive(false)
            return true
        elseif key == "return" or key == "kpenter" then
            setSearchActive(false)
            return true
        elseif key == "backspace" then
            Cargo.searchText = Cargo.searchText:sub(1, -2)
            return true
        elseif key == "tab" then
            return true
        end
        return true
    end

    if key == "escape" then
        if Cargo.contextMenu.visible then
            ContextMenu.hide(Cargo)
            return true
        end
        setSearchActive(false)
        Cargo.visible = false
        return true
    end
    return false
end

function Cargo.textinput(text)
    if not Cargo.visible then return false end

    if Cargo._searchInputActive then
        Cargo.searchText = Cargo.searchText .. text
        return true
    end

    return false
end

function Cargo.dropItem(player, itemId)
    return Actions.dropItem(player, itemId)
end

function Cargo.useItem(player, itemId)
    return Actions.useItem(player, itemId)
end

return Cargo
