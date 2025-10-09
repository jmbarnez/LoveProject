--[[
    Ship Hotbar Preview
    
    Handles hotbar integration and preview including:
    - Hotbar slot rendering
    - Hotbar state management
    - Equipment to hotbar mapping
    - Hotbar interaction handling
]]

local Theme = require("src.core.theme")
local HotbarSystem = require("src.systems.hotbar")
local IconSystem = require("src.core.icon_system")

local HotbarPreview = {}

function HotbarPreview.draw(self, x, y, w, h)
    local state = self.state
    if not state then return end
    
    local hotbarPreview = state:getHotbarPreview()
    if not hotbarPreview or #hotbarPreview == 0 then
        HotbarPreview.drawNoHotbar(x, y, w, h)
        return
    end
    
    -- Hotbar background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Hotbar border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Title
    Theme.setColor(Theme.colors.text)
    Theme.setFont("medium")
    love.graphics.print("Hotbar Preview", x + 12, y + 12)
    
    -- Draw hotbar slots
    local slotSize = 48
    local slotSpacing = 4
    local slotsPerRow = math.floor((w - 24) / (slotSize + slotSpacing))
    local startX = x + 12
    local startY = y + 40
    
    for i, slot in ipairs(hotbarPreview) do
        local col = (i - 1) % slotsPerRow
        local row = math.floor((i - 1) / slotsPerRow)
        local slotX = startX + col * (slotSize + slotSpacing)
        local slotY = startY + row * (slotSize + slotSpacing)
        
        local isSelected = state.selectedHotbarSlot == i
        local isHovered = state.hoveredHotbarSlot == i
        
        HotbarPreview.drawHotbarSlot(self, slot, slotX, slotY, slotSize, slotSize, i, isSelected, isHovered)
    end
end

function HotbarPreview.drawNoHotbar(x, y, w, h)
    -- Background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- No hotbar message
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("medium")
    local text = "No hotbar items"
    local textW = Theme.fonts.medium:getWidth(text)
    local textH = Theme.fonts.medium:getHeight()
    local textX = x + (w - textW) * 0.5
    local textY = y + (h - textH) * 0.5
    love.graphics.print(text, textX, textY)
end

function HotbarPreview.drawHotbarSlot(self, slot, x, y, w, h, index, selected, hovered)
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
    
    if slot and slot.item then
        -- Draw item icon
        local iconSize = w - 8
        local iconX = x + 4
        local iconY = y + 4
        
        if slot.item.icon then
            IconSystem.drawIcon(slot.item.icon, iconX, iconY, iconSize)
        else
            -- Fallback icon
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)
        end
        
        -- Draw item label
        local label = slot.label or slot.item
        if label then
            Theme.setColor(Theme.colors.text)
            Theme.setFont("xsmall")
            local textW = Theme.fonts.xsmall:getWidth(label)
            local textH = Theme.fonts.xsmall:getHeight()
            local textX = x + (w - textW) * 0.5
            local textY = y + h - textH - 2
            love.graphics.print(label, textX, textY)
        end
        
        -- Draw hotkey
        local hotkey = slot.hotkey or tostring(index)
        Theme.setColor(Theme.colors.textSecondary)
        Theme.setFont("xsmall")
        local hotkeyW = Theme.fonts.xsmall:getWidth(hotkey)
        local hotkeyX = x + w - hotkeyW - 2
        local hotkeyY = y + 2
        love.graphics.print(hotkey, hotkeyX, hotkeyY)
    else
        -- Empty slot
        Theme.setColor(Theme.colors.textSecondary)
        Theme.setFont("small")
        local text = tostring(index)
        local textW = Theme.fonts.small:getWidth(text)
        local textH = Theme.fonts.small:getHeight()
        local textX = x + (w - textW) * 0.5
        local textY = y + (h - textH) * 0.5
        love.graphics.print(text, textX, textY)
    end
    
    -- Store slot rect for interaction
    state.hotbarRects = state.hotbarRects or {}
    state.hotbarRects[index] = {x = x, y = y, w = w, h = h}
end

function HotbarPreview.buildHotbarPreview(self, player, gridOverride)
    local state = self.state
    local slots = HotbarSystem.slots or {}
    local totalSlots = #slots
    local preview = {}
    local grid = gridOverride or (player.components and player.components.equipment and player.components.equipment.grid) or {}
    
    -- Seed with current hotbar content for context
    for i = 1, totalSlots do
        local slot = slots[i]
        if slot and slot.item then
            local label = slot.item
            local idx = tostring(slot.item):match("^turret_slot_(%d+)$")
            if idx then
                idx = tonumber(idx)
                if grid[idx] then
                    label = state:resolveModuleDisplayName(grid[idx]) or label
                end
            end
            preview[i] = {
                item = slot.item,
                label = label,
                origin = "actual",
                gridIndex = idx
            }
        else
            preview[i] = {
                item = nil,
                label = nil,
                origin = "empty",
                gridIndex = nil
            }
        end
    end
    
    -- Fill remaining slots with available equipment
    local nextSlot = totalSlots + 1
    for gridIndex, gridSlot in ipairs(grid) do
        if gridSlot and gridSlot.id and not HotbarPreview.isSlotInHotbar(preview, gridIndex) then
            if nextSlot <= totalSlots + 10 then -- Limit preview size
                preview[nextSlot] = {
                    item = gridSlot.module or {id = gridSlot.id, name = gridSlot.name},
                    label = state:resolveModuleDisplayName(gridSlot),
                    origin = "available",
                    gridIndex = gridIndex
                }
                nextSlot = nextSlot + 1
            end
        end
    end
    
    state:setHotbarPreview(preview)
    return preview
end

function HotbarPreview.isSlotInHotbar(preview, gridIndex)
    for _, slot in ipairs(preview) do
        if slot.gridIndex == gridIndex then
            return true
        end
    end
    return false
end

function HotbarPreview.handleClick(self, mx, my, button)
    if button ~= 1 then return false end
    
    local state = self.state
    if not state.hotbarRects then return false end
    
    for index, rect in pairs(state.hotbarRects) do
        if mx >= rect.x and mx < rect.x + rect.w and
           my >= rect.y and my < rect.y + rect.h then
            state.selectedHotbarSlot = index
            return true
        end
    end
    
    return false
end

function HotbarPreview.handleRightClick(self, mx, my, button)
    if button ~= 2 then return false end
    
    local state = self.state
    if not state.hotbarRects then return false end
    
    for index, rect in pairs(state.hotbarRects) do
        if mx >= rect.x and mx < rect.x + rect.w and
           my >= rect.y and my < rect.y + rect.h then
            local hotbarPreview = state:getHotbarPreview()
            local slot = hotbarPreview[index]
            
            if slot and slot.item then
                local contextMenu = {
                    visible = true,
                    x = mx,
                    y = my,
                    slot = slot,
                    slotIndex = index,
                    options = {
                        {text = "Remove from Hotbar", action = "remove"},
                        {text = "Configure", action = "configure"}
                    }
                }
                state:setContextMenu(contextMenu)
                return true
            end
        end
    end
    
    return false
end

function HotbarPreview.handleHover(self, mx, my)
    local state = self.state
    if not state.hotbarRects then return false end
    
    for index, rect in pairs(state.hotbarRects) do
        if mx >= rect.x and mx < rect.x + rect.w and
           my >= rect.y and my < rect.y + rect.h then
            state.hoveredHotbarSlot = index
            return true
        end
    end
    
    state.hoveredHotbarSlot = nil
    return false
end

function HotbarPreview.removeFromHotbar(self, slotIndex)
    local state = self.state
    local hotbarPreview = state:getHotbarPreview()
    local slot = hotbarPreview[slotIndex]
    
    if slot and slot.origin == "actual" then
        -- Remove from actual hotbar
        local HotbarSystem = require("src.systems.hotbar")
        if HotbarSystem.removeSlot then
            HotbarSystem.removeSlot(slotIndex)
        end
        
        -- Update preview
        self:buildHotbarPreview(state:getPlayer())
        return true
    end
    
    return false
end

function HotbarPreview.addToHotbar(self, slotIndex)
    local state = self.state
    local hotbarPreview = state:getHotbarPreview()
    local slot = hotbarPreview[slotIndex]
    
    if slot and slot.origin == "available" and slot.gridIndex then
        -- Add to hotbar
        local HotbarSystem = require("src.systems.hotbar")
        if HotbarSystem.addSlot then
            HotbarSystem.addSlot("turret_slot_" .. slot.gridIndex)
        end
        
        -- Update preview
        self:buildHotbarPreview(state:getPlayer())
        return true
    end
    
    return false
end

return HotbarPreview
