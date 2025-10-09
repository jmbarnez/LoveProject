--[[
    Inventory Context Menu
    
    Handles context menu rendering and interaction including:
    - Context menu display
    - Menu option handling
    - Item actions
    - Menu positioning
]]

local Theme = require("src.core.theme")

local ContextMenu = {}

function ContextMenu.draw(self, x, y, w, h)
    local state = self.state
    if not state then return end
    
    local contextMenu = state:getContextMenu()
    if not contextMenu or not contextMenu.visible then return end
    
    local menuX = contextMenu.x
    local menuY = contextMenu.y
    local menuW = 150
    local menuH = #contextMenu.options * 24 + 8
    
    -- Ensure menu stays within screen bounds
    local screenW, screenH = love.graphics.getDimensions()
    if menuX + menuW > screenW then
        menuX = screenW - menuW - 10
    end
    if menuY + menuH > screenH then
        menuY = screenH - menuH - 10
    end
    
    -- Context menu background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", menuX, menuY, menuW, menuH)
    
    -- Context menu border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", menuX, menuY, menuW, menuH)
    
    -- Context menu options
    for i, option in ipairs(contextMenu.options) do
        local optionY = menuY + 4 + (i - 1) * 24
        local optionH = 24
        
        -- Option background
        Theme.setColor(Theme.colors.bg2)
        love.graphics.rectangle("fill", menuX + 2, optionY, menuW - 4, optionH)
        
        -- Option text
        Theme.setColor(Theme.colors.text)
        Theme.setFont("small")
        love.graphics.print(option.text, menuX + 8, optionY + 6)
    end
end

function ContextMenu.handleClick(self, mx, my, button)
    if button ~= 1 then return false end
    
    local state = self.state
    local contextMenu = state:getContextMenu()
    if not contextMenu or not contextMenu.visible then return false end
    
    local menuX = contextMenu.x
    local menuY = contextMenu.y
    local menuW = 150
    local menuH = #contextMenu.options * 24 + 8
    
    -- Check if click is within context menu
    if mx >= menuX and mx < menuX + menuW and my >= menuY and my < menuY + menuH then
        -- Handle context menu option click
        local optionIndex = math.floor((my - menuY - 4) / 24) + 1
        if optionIndex >= 1 and optionIndex <= #contextMenu.options then
            local option = contextMenu.options[optionIndex]
            ContextMenu.handleAction(self, option.action, contextMenu)
            return true
        end
    end
    
    -- Click outside context menu - close it
    ContextMenu.close(self)
    return true
end

function ContextMenu.handleAction(self, action, contextMenu)
    local state = self.state
    local item = contextMenu.item
    
    if not item then
        ContextMenu.close(self)
        return
    end
    
    if action == "use" then
        ContextMenu.useItem(self, item)
    elseif action == "equip" then
        ContextMenu.equipItem(self, item)
    elseif action == "drop" then
        ContextMenu.dropItem(self, item)
    elseif action == "info" then
        ContextMenu.showItemInfo(self, item)
    end
    
    ContextMenu.close(self)
end

function ContextMenu.useItem(self, item)
    local state = self.state
    local player = state:getPlayer()
    
    if not player or not player.components or not player.components.cargo then
        return
    end
    
    local cargo = player.components.cargo
    
    -- Check if item is usable
    if item.type == "consumable" or item.type == "utility" then
        -- Use the item
        if cargo:useItem(item.id) then
            local Notifications = require("src.ui.notifications")
            Notifications.add("Used " .. (item.name or item.id), "success")
        else
            local Notifications = require("src.ui.notifications")
            Notifications.add("Cannot use " .. (item.name or item.id), "error")
        end
    else
        local Notifications = require("src.ui.notifications")
        Notifications.add("Item is not usable", "error")
    end
end

function ContextMenu.equipItem(self, item)
    local state = self.state
    local player = state:getPlayer()
    
    if not player or not player.components or not player.components.equipment then
        return
    end
    
    local equipment = player.components.equipment
    
    -- Check if item is equippable
    if item.type == "turret" or item.type == "shield" or item.type == "utility" then
        -- Try to equip the item
        if equipment:equipItem(item) then
            local Notifications = require("src.ui.notifications")
            Notifications.add("Equipped " .. (item.name or item.id), "success")
        else
            local Notifications = require("src.ui.notifications")
            Notifications.add("Cannot equip " .. (item.name or item.id), "error")
        end
    else
        local Notifications = require("src.ui.notifications")
        Notifications.add("Item is not equippable", "error")
    end
end

function ContextMenu.dropItem(self, item)
    local state = self.state
    local player = state:getPlayer()
    
    if not player or not player.components or not player.components.cargo then
        return
    end
    
    local cargo = player.components.cargo
    
    -- Drop the item
    if cargo:dropItem(item.id, item.quantity or 1) then
        local Notifications = require("src.ui.notifications")
        Notifications.add("Dropped " .. (item.name or item.id), "success")
    else
        local Notifications = require("src.ui.notifications")
        Notifications.add("Cannot drop " .. (item.name or item.id), "error")
    end
end

function ContextMenu.showItemInfo(self, item)
    -- Show item info tooltip or panel
    -- This would typically show detailed item information
    local state = self.state
    state:setHoveredItem(item)
    state:setHoverTimer(5.0) -- Show tooltip for 5 seconds
end

function ContextMenu.close(self)
    local state = self.state
    state:setContextMenuActive(false)
    state:setContextMenu({visible = false, x = 0, y = 0, item = nil, options = {}})
end

function ContextMenu.isPointInside(self, mx, my)
    local state = self.state
    local contextMenu = state:getContextMenu()
    if not contextMenu or not contextMenu.visible then return false end
    
    local menuX = contextMenu.x
    local menuY = contextMenu.y
    local menuW = 150
    local menuH = #contextMenu.options * 24 + 8
    
    return mx >= menuX and mx < menuX + menuW and my >= menuY and my < menuY + menuH
end

function ContextMenu.getMenuRect(self)
    local state = self.state
    local contextMenu = state:getContextMenu()
    if not contextMenu or not contextMenu.visible then return nil end
    
    local menuX = contextMenu.x
    local menuY = contextMenu.y
    local menuW = 150
    local menuH = #contextMenu.options * 24 + 8
    
    return {x = menuX, y = menuY, w = menuW, h = menuH}
end

return ContextMenu
