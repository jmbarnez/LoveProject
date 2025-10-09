--[[
    Inventory Item Grid
    
    Handles item grid rendering and layout including:
    - Grid layout and rendering
    - Item slot rendering
    - Hover effects
    - Selection highlighting
]]

local Theme = require("src.core.theme")
local IconSystem = require("src.core.icon_system")
local Content = require("src.content.content")

local ItemGrid = {}

local CARGO_SLOT_SIZE = 48

function ItemGrid.draw(self, x, y, w, h)
    local state = self.state
    if not state then return end
    
    local player = state:getPlayer()
    if not player or not player.components or not player.components.cargo then
        ItemGrid.drawNoCargo(x, y, w, h)
        return
    end
    
    local cargo = player.components.cargo
    local items = cargo:getAllItems()
    
    -- Apply filters
    local InventoryFilters = require("src.ui.inventory.filters")
    local filteredItems = InventoryFilters.filterAndSortItems(
        items, 
        state:getSearchText(), 
        state:getSortBy(), 
        state:getSortOrder()
    )
    
    -- Calculate grid layout
    local cols = math.floor(w / (CARGO_SLOT_SIZE + 4))
    local rows = math.ceil(#filteredItems / cols)
    local startX = x + 4
    local startY = y + 4
    
    -- Draw items
    for i, item in ipairs(filteredItems) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local itemX = startX + col * (CARGO_SLOT_SIZE + 4)
        local itemY = startY + row * (CARGO_SLOT_SIZE + 4)
        
        local isHovered = state:getHoveredItem() == item
        local isDragged = state:getDragItem() == item
        
        ItemGrid.drawItemSlot(self, item, itemX, itemY, CARGO_SLOT_SIZE, CARGO_SLOT_SIZE, i, isHovered, isDragged)
    end
    
    -- Update scroll max
    local totalHeight = rows * (CARGO_SLOT_SIZE + 4) + 8
    state:setScrollMax(math.max(0, totalHeight - h))
    
    -- Draw drag preview
    local drag = state:getDrag()
    if drag then
        ItemGrid.drawDragPreview(self, drag.x, drag.y, CARGO_SLOT_SIZE, CARGO_SLOT_SIZE)
    end
end

function ItemGrid.drawNoCargo(x, y, w, h)
    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- No cargo message
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("medium")
    local text = "No cargo system"
    local textW = Theme.fonts.medium:getWidth(text)
    local textH = Theme.fonts.medium:getHeight()
    local textX = x + (w - textW) * 0.5
    local textY = y + (h - textH) * 0.5
    love.graphics.print(text, textX, textY)
end

function ItemGrid.drawItemSlot(self, item, x, y, w, h, index, hovered, dragged)
    local state = self.state
    
    -- Slot background
    local bgColor = hovered and Theme.colors.bg3 or Theme.colors.bg2
    if dragged then
        bgColor = Theme.colors.accent
    end
    
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Slot border
    local borderColor = hovered and Theme.colors.borderBright or Theme.colors.border
    if dragged then
        borderColor = Theme.colors.accent
    end
    
    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    if item then
        -- Item icon
        local iconSize = w - 8
        local iconX = x + 4
        local iconY = y + 4
        
        if item.icon then
            IconSystem.drawIcon(item.icon, iconX, iconY, iconSize)
        else
            -- Fallback icon
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)
        end
        
        -- Item quantity
        if item.quantity and item.quantity > 1 then
            Theme.setColor(Theme.colors.text)
            Theme.setFont("xsmall")
            local quantityText = tostring(item.quantity)
            local quantityW = Theme.fonts.xsmall:getWidth(quantityText)
            local quantityX = x + w - quantityW - 2
            local quantityY = y + h - 12
            love.graphics.print(quantityText, quantityX, quantityY)
        end
        
        -- Rarity indicator
        if item.rarity then
            local rarityColor = Theme.colors.rarity[item.rarity] or Theme.colors.text
            Theme.setColor(rarityColor)
            love.graphics.rectangle("fill", x, y, 4, h)
        end
        
        -- Store item rect for interaction
        state.itemRects = state.itemRects or {}
        state.itemRects[index] = {x = x, y = y, w = w, h = h, item = item}
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
end

function ItemGrid.drawDragPreview(self, x, y, w, h)
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

function ItemGrid.getItemAtPosition(self, mx, my)
    local state = self.state
    if not state.itemRects then return nil end
    
    for index, rect in pairs(state.itemRects) do
        if mx >= rect.x and mx < rect.x + rect.w and
           my >= rect.y and my < rect.y + rect.h then
            return rect.item, index, rect
        end
    end
    
    return nil
end

function ItemGrid.handleItemClick(self, mx, my, button)
    local item, index, rect = ItemGrid.getItemAtPosition(self, mx, my)
    if not item then return false end
    
    local state = self.state
    
    if button == 1 then
        -- Left click - select item
        state:setHoveredItem(item)
        return true
    elseif button == 2 then
        -- Right click - show context menu
        local contextMenu = {
            visible = true,
            x = mx,
            y = my,
            item = item,
            options = ItemGrid.getItemContextOptions(item)
        }
        state:setContextMenu(contextMenu)
        return true
    end
    
    return false
end

function ItemGrid.handleItemHover(self, mx, my)
    local item, index, rect = ItemGrid.getItemAtPosition(self, mx, my)
    local state = self.state
    
    if item then
        state:setHoveredItem(item)
        return true
    else
        state:setHoveredItem(nil)
        return false
    end
end

function ItemGrid.startDrag(self, mx, my)
    local item, index, rect = ItemGrid.getItemAtPosition(self, mx, my)
    if not item then return false end
    
    local state = self.state
    state:setDragItem(item)
    state:setDragStartIndex(index)
    state:setDrag({x = mx - CARGO_SLOT_SIZE * 0.5, y = my - CARGO_SLOT_SIZE * 0.5})
    
    return true
end

function ItemGrid.updateDrag(self, mx, my)
    local state = self.state
    local drag = state:getDrag()
    
    if drag then
        drag.x = mx - CARGO_SLOT_SIZE * 0.5
        drag.y = my - CARGO_SLOT_SIZE * 0.5
    end
end

function ItemGrid.endDrag(self, mx, my)
    local state = self.state
    local dragItem = state:getDragItem()
    local dragStartIndex = state:getDragStartIndex()
    
    if not dragItem or not dragStartIndex then return false end
    
    -- Check if dropped on another item
    local targetItem, targetIndex, targetRect = ItemGrid.getItemAtPosition(self, mx, my)
    if targetItem and targetIndex ~= dragStartIndex then
        -- Swap items
        local player = state:getPlayer()
        if player and player.components and player.components.cargo then
            local cargo = player.components.cargo
            cargo:swapItems(dragStartIndex, targetIndex)
            return true
        end
    end
    
    -- Clear drag state
    state:setDrag(nil)
    state:setDragItem(nil)
    state:setDragStartIndex(nil)
    
    return false
end

function ItemGrid.getItemContextOptions(item)
    local options = {}
    
    if item then
        table.insert(options, {text = "Use", action = "use"})
        table.insert(options, {text = "Equip", action = "equip"})
        table.insert(options, {text = "Drop", action = "drop"})
        table.insert(options, {text = "Info", action = "info"})
    end
    
    return options
end

return ItemGrid
