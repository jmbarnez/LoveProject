--[[
    Ship Equipment Grid
    
    Handles equipment grid rendering and logic including:
    - Grid layout and rendering
    - Slot management
    - Drag and drop visualization
    - Slot type handling
]]

local Theme = require("src.core.theme")
local Content = require("src.content.content")
local IconSystem = require("src.core.icon_system")

local EquipmentGrid = {}

function EquipmentGrid.draw(self, x, y, w, h)
    local state = self.state
    if not state then return end
    
    local grid = state:getEquipmentGrid()
    if not grid then return end
    
    -- Grid background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Grid border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Draw grid slots
    local slotSize = 64
    local padding = 8
    local cols = math.floor((w - padding) / (slotSize + padding))
    local rows = math.ceil(#grid / cols)
    
    local startX = x + padding
    local startY = y + padding
    
    for i, slot in ipairs(grid) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local slotX = startX + col * (slotSize + padding)
        local slotY = startY + row * (slotSize + padding)
        
        local isSelected = state:getSelectedSlot() == i
        local isHovered = state:getHoveredSlot() == i
        
        EquipmentGrid.drawSlot(self, slot, slotX, slotY, slotSize, slotSize, i, isSelected, isHovered)
    end
    
    -- Draw drag preview
    local drag = state:getDrag()
    if drag then
        EquipmentGrid.drawDragPreview(self, drag.x, drag.y, slotSize, slotSize)
    end
end

function EquipmentGrid.drawSlot(self, slot, x, y, w, h, index, selected, hovered)
    local state = self.state
    
    -- Slot background
    local bgColor = selected and Theme.colors.accent or (hovered and Theme.colors.bg3 or Theme.colors.bg2)
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Slot border
    local borderColor = selected and Theme.colors.borderBright or Theme.colors.border
    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    if slot and slot.id then
        -- Draw module icon
        local iconSize = w - 8
        local iconX = x + 4
        local iconY = y + 4
        
        if slot.module and slot.module.icon then
            IconSystem.drawIcon(slot.module.icon, iconX, iconY, iconSize)
        else
            -- Fallback icon
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)
        end
        
        -- Draw module name
        local moduleName = state:resolveModuleDisplayName(slot)
        if moduleName then
            Theme.setColor(Theme.colors.text)
            Theme.setFont("xsmall")
            local textW = Theme.fonts.xsmall:getWidth(moduleName)
            local textH = Theme.fonts.xsmall:getHeight()
            local textX = x + (w - textW) * 0.5
            local textY = y + h - textH - 2
            love.graphics.print(moduleName, textX, textY)
        end
        
        -- Draw slot type indicator
        local slotType = state:getSlotType(slot)
        if slotType then
            Theme.setColor(Theme.colors.textSecondary)
            Theme.setFont("xsmall")
            local typeText = string.upper(slotType:sub(1, 1))
            local typeW = Theme.fonts.xsmall:getWidth(typeText)
            local typeX = x + w - typeW - 2
            local typeY = y + 2
            love.graphics.print(typeText, typeX, typeY)
        end
        
        -- Draw enabled/disabled indicator
        if slot.enabled ~= nil then
            local indicatorColor = slot.enabled and Theme.colors.success or Theme.colors.danger
            Theme.setColor(indicatorColor)
            love.graphics.circle("fill", x + w - 6, y + 6, 3)
        end
    else
        -- Empty slot
        Theme.setColor(Theme.colors.textSecondary)
        Theme.setFont("small")
        local text = "+"
        local textW = Theme.fonts.small:getWidth(text)
        local textH = Theme.fonts.small:getHeight()
        local textX = x + (w - textW) * 0.5
        local textY = y + (h - textH) * 0.5
        love.graphics.print(text, textX, textY)
    end
    
    -- Store slot rect for interaction
    state.slotRects = state.slotRects or {}
    state.slotRects[index] = {x = x, y = y, w = w, h = h}
end

function EquipmentGrid.drawDragPreview(self, x, y, w, h)
    local state = self.state
    local dragItem = state:getDragItem()
    
    if not dragItem then return end
    
    -- Semi-transparent background
    Theme.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 0.5)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    Theme.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Item icon
    if dragItem.icon then
        local iconSize = w - 8
        local iconX = x + 4
        local iconY = y + 4
        IconSystem.drawIcon(dragItem.icon, iconX, iconY, iconSize)
    end
end

function EquipmentGrid.getSlotAtPosition(self, mx, my)
    local state = self.state
    if not state.slotRects then return nil end
    
    for index, rect in pairs(state.slotRects) do
        if mx >= rect.x and mx < rect.x + rect.w and
           my >= rect.y and my < rect.y + rect.h then
            return index, rect
        end
    end
    
    return nil
end

function EquipmentGrid.handleSlotClick(self, mx, my, button)
    if button ~= 1 then return false end
    
    local slotIndex, rect = EquipmentGrid.getSlotAtPosition(self, mx, my)
    if not slotIndex then return false end
    
    local state = self.state
    local grid = state:getEquipmentGrid()
    local slot = grid[slotIndex]
    
    if slot and slot.id then
        -- Slot has item - select it
        state:setSelectedSlot(slotIndex)
        return true
    else
        -- Empty slot - could start drag from inventory
        state:setSelectedSlot(slotIndex)
        return true
    end
end

function EquipmentGrid.handleSlotRightClick(self, mx, my, button)
    if button ~= 2 then return false end
    
    local slotIndex, rect = EquipmentGrid.getSlotAtPosition(self, mx, my)
    if not slotIndex then return false end
    
    local state = self.state
    local grid = state:getEquipmentGrid()
    local slot = grid[slotIndex]
    
    if slot and slot.id then
        -- Show context menu for equipped item
        local contextMenu = {
            visible = true,
            x = mx,
            y = my,
            slot = slot,
            options = {
                {text = "Unequip", action = "unequip"},
                {text = "Info", action = "info"}
            }
        }
        state:setContextMenu(contextMenu)
        return true
    end
    
    return false
end

function EquipmentGrid.startDrag(self, slotIndex)
    local state = self.state
    local grid = state:getEquipmentGrid()
    local slot = grid[slotIndex]
    
    if not slot or not slot.id then return false end
    
    state:setDragStartSlot(slotIndex)
    state:setDragItem(slot.module or {id = slot.id, name = slot.name})
    state:setDrag({x = 0, y = 0}) -- Will be updated by mouse movement
    
    return true
end

function EquipmentGrid.updateDrag(self, mx, my)
    local state = self.state
    local drag = state:getDrag()
    
    if drag then
        drag.x = mx - 32 -- Center on cursor
        drag.y = my - 32
    end
end

function EquipmentGrid.endDrag(self, mx, my)
    local state = self.state
    local dragStartSlot = state:getDragStartSlot()
    local dragItem = state:getDragItem()
    
    if not dragStartSlot or not dragItem then return false end
    
    -- Check if dropped on another slot
    local targetSlot, rect = EquipmentGrid.getSlotAtPosition(self, mx, my)
    if targetSlot and targetSlot ~= dragStartSlot then
        -- Swap items
        local grid = state:getEquipmentGrid()
        local sourceSlot = grid[dragStartSlot]
        local targetSlotData = grid[targetSlot]
        
        grid[dragStartSlot] = targetSlotData
        grid[targetSlot] = sourceSlot
        
        -- Update player equipment
        if state:getPlayer() and state:getPlayer().components and state:getPlayer().components.equipment then
            state:getPlayer().components.equipment.grid = grid
        end
        
        return true
    end
    
    -- Clear drag state
    state:setDrag(nil)
    state:setDragStartSlot(nil)
    state:setDragItem(nil)
    
    return false
end

function EquipmentGrid.handleSlotHover(self, mx, my)
    local slotIndex, rect = EquipmentGrid.getSlotAtPosition(self, mx, my)
    local state = self.state
    
    if slotIndex then
        state:setHoveredSlot(slotIndex)
        return true
    else
        state:setHoveredSlot(nil)
        return false
    end
end

return EquipmentGrid
