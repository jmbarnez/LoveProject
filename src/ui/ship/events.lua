local UIUtils = require("src.ui.common.utils")
local CargoUI = require("src.ui.cargo")
local HotbarSystem = require("src.systems.hotbar")
local Notifications = require("src.ui.notifications")
local Util = require("src.core.util")
local Dropdowns = require("src.ui.ship.dropdowns")

local Events = {}

local function getContentBounds(state)
    if state.window and state.window.visible then
        return state.window:getContentBounds()
    end
    return state.activeContentBounds
end

function Events.mousepressed(state, x, y, button, player)
    if not x or not y or not button then
        return false, false
    end

    local content = getContentBounds(state)
    if content and x and y and UIUtils.pointInRect(x, y, content) and state.slotDropdowns then
        for _, dropdown in ipairs(state.slotDropdowns) do
            if dropdown:mousepressed(x, y, button) then
                if state.window and state.window.dragging then
                    state.window.dragging = false
                end
                return true, false
            end
        end
    end

    local handled = false
    if state.window and state.window.visible then
        handled = state.window:mousepressed(x, y, button)
        if handled then
            return true, false
        end
    end

    if not content or not player or type(player) ~= "table" then
        return false, false
    end

    if button == 1 and state.hotbarButtons then
        for index, hbButton in ipairs(state.hotbarButtons) do
            local rect = hbButton and hbButton.rect
            if hbButton and hbButton.enabled and rect and UIUtils.pointInRect(x, y, rect) then
                local playerModule = player.components and player.components.equipment and player.components.equipment.grid and player.components.equipment.grid[index]
                if playerModule and playerModule.module then
                    local currentValue = hbButton.value or 0
                    local totalSlots = #HotbarSystem.slots
                    local attempts = 0
                    local foundSlot = false
                    local newValue = currentValue

                    while attempts < totalSlots + 1 and not foundSlot do
                        newValue = newValue + 1
                        if newValue > totalSlots then
                            newValue = 0
                        end

                        local slotOccupied = false
                        if newValue > 0 and player.components and player.components.equipment and player.components.equipment.grid then
                            for j, gridData in ipairs(player.components.equipment.grid) do
                                if gridData.hotbarSlot == newValue and j ~= index and gridData.module then
                                    slotOccupied = true
                                    break
                                end
                            end
                        end

                        if newValue == 0 or not slotOccupied then
                            foundSlot = true
                        end

                        attempts = attempts + 1
                    end

                    if foundSlot then
                        hbButton.value = newValue
                        if hbButton.value == 0 then
                            playerModule.hotbarSlot = nil
                        else
                            playerModule.hotbarSlot = hbButton.value
                        end

                        local keyName
                        if hbButton.value == 0 then
                            keyName = "Auto"
                        else
                            keyName = HotbarSystem.getSlotKey and HotbarSystem.getSlotKey(hbButton.value) or ("hotbar_" .. tostring(hbButton.value))
                        end

                        if Notifications and Notifications.add then
                            Notifications.add(string.format("Slot %d bound to %s", index, keyName), "info")
                        end

                        if HotbarSystem.populateFromPlayer then
                            HotbarSystem.populateFromPlayer(player, nil, index)
                        end

                        if CargoUI and CargoUI.refresh then
                            CargoUI.refresh()
                        end

                        Dropdowns.refresh(state, player)
                    end
                    return true, false
                end
            end
        end
    end

    if button == 1 and state.removeButtons then
        for index, removeButton in ipairs(state.removeButtons) do
            local rect = removeButton and removeButton.rect
            if rect and UIUtils.pointInRect(x, y, rect) then
                local unequipped = player.unequipModule and player:unequipModule(index)
                if unequipped then
                    Dropdowns.refresh(state, player)
                    if CargoUI and CargoUI.refresh then
                        CargoUI.refresh()
                    end
                    if HotbarSystem.populateFromPlayer then
                        HotbarSystem.populateFromPlayer(player, nil, index)
                    end
                end
                return true, false
            end
        end
    end

    return false, false
end

function Events.mousereleased(state, x, y, button)
    if not x or not y or not button then
        return false, false
    end

    if state.window and state.window.visible then
        local handled = state.window:mousereleased(x, y, button)
        if handled then
            return true, false
        end
    end

    if state.slotDropdowns then
        for _, dropdown in ipairs(state.slotDropdowns) do
            if dropdown.mousereleased and dropdown:mousereleased(x, y, button) then
                return true, false
            end
        end
    end

    return false, false
end

function Events.mousemoved(state, x, y, dx, dy)
    if state.window and state.window.visible then
        if state.window:mousemoved(x, y, dx, dy) then
            return true
        end
    end

    if state.slotDropdowns then
        for _, dropdown in ipairs(state.slotDropdowns) do
            dropdown:mousemoved(x, y)
        end
    end

    return false
end

function Events.wheelmoved(state, x, y, dx, dy)
    if dy == nil or dy == 0 then
        return false
    end

    local handled = false
    local scrollDelta = dy * 28

    if state.statsViewRect and x and y and UIUtils.pointInRect(x, y, state.statsViewRect) then
        local minScroll = state.statsViewRect.minScroll or 0
        state.statsScroll = Util.clamp((state.statsScroll or 0) + scrollDelta, minScroll, 0)
        handled = true
    end

    if state.slotViewRect and x and y and UIUtils.pointInRect(x, y, state.slotViewRect) then
        local minScroll = state.slotViewRect.minScroll or 0
        state.slotScroll = Util.clamp((state.slotScroll or 0) + scrollDelta, minScroll, 0)
        handled = true
    end

    return handled
end

return Events
